defmodule Neovim.App do
  use Application
  def start(_type, _args), do: 
    Neovim.App.Sup.start_link

  defmodule Sup do
    use Supervisor

    def start_link, do: Supervisor.start_link(__MODULE__,[])

    def init([]) do
      supervise([
        worker(Neovim.Link,[Application.get_env(:neovim,:link,:stdio)]),
        worker(Neovim.Events,[])
      ], strategy: :one_for_all)
    end
  end
end

defmodule Neovim.Events do
  def start_link, do:
    GenEvent.start_link(name: __MODULE__)
end

defmodule Neovim.Logger do
  use GenEvent

  def handle_event({level,_leader,{Logger,msg,_ts,_md}},state) do
    clean_msg = msg |> to_string |> String.split("\n") |> hd |> String.replace("\"","\\\"")
    Neovim.vim_command ~s/echo "#{level}: #{clean_msg}"/
    {:ok,state}
  catch _, _ -> {:ok,state}
  end

  def handle_call({:configure,_opts},state), do:
    {:ok,:ok,state}
end


defmodule Neovim.Link do
  use GenServer
  alias :procket, as: Socket
  @msg_req 0
  @msg_resp 1
  @msg_notify 2

  def start_link(link_spec), 
   do: GenServer.start_link(__MODULE__,link_spec, name: __MODULE__)

  def init(link_spec) do
    Process.flag(:trap_exit,true)
    {fdin,fdout} = open(link_spec)
    port = Port.open({:fd,fdin,fdout}, [:stream,:binary])
    Process.link(port)
    {:ok,%{link_spec: link_spec, port: port, buf: "", req_id: 0, reqs: HashDict.new}}
  end

  def handle_call({func,args},from,%{port: port}=state) do
    req_id = state.req_id+1
    Port.command port, MessagePack.pack!([@msg_req,req_id,func,args])
    {:noreply,%{state|req_id: req_id, reqs: Dict.put(state.reqs,req_id,from)}}
  end

  def handle_info({port,{:data,data}},%{reqs: reqs,buf: buf}=state) do
    data = buf<>data
    case MessagePack.unpack_once(data) do
      {:ok,{[@msg_notify,name,params],tail}}->
        GenEvent.notify Neovim.Events, {:"#{name}",params}
        {:noreply,%{state|buf: tail}}
      {:ok,{[@msg_resp,req_id,err,resp],tail}}->
        reply = if err, do: {:error,err}, else: {:ok, resp}
        reqs = case Dict.pop(reqs,req_id) do
          {nil,_} -> reqs
          {reply_to,reqs} -> GenServer.reply(reply_to,reply); reqs
        end
        {:noreply,%{state|buf: tail, reqs: reqs}}
      {:ok,{[@msg_req,req_id,modfun,args],tail}}->
        {modparts,[fun]} = modfun |> String.split(".") |> Enum.split(-1)
        spawn fn->
          res = try do apply(Module.concat(modparts),:"#{fun}",args)
                    catch _, _ -> {:error,:exception} end
          Port.command port, MessagePack.pack!([@msg_resp,req_id,nil,res])
        end
        {:noreply,%{state|buf: tail}}
      {:error,_}->{:noreply,%{state|buf: data}}
    end
  end
  def handle_info({:EXIT,port,_},%{port: port,link_spec: :stdio}=state) do
    System.halt(0) # if the port die in stdio mode, it means the link is broken, kill the app
    {:noreply,state}
  end
  def handle_info({:EXIT,port,reason},%{port: port}=state) do
    {:stop,reason,state}
  end

  def terminate(_reason,state) do
    Port.close(state.port)
  catch _, _ -> :ok
  end

  defp parse_ip(ip) do
    case :inet.parse_address(ip) do
      {:ok,{ip1,ip2,ip3,ip4}}->
        {:ipv4,<<ip1,ip2,ip3,ip4>>}
      {:ok,{ip1,ip2,ip3,ip4,ip5,ip6,ip7,ip8}}->
        {:ipv6,<<ip1::16,ip2::16,ip3::16,ip4::16,ip5::16,ip6::16,ip7::16,ip8::16>>}
    end
  end

  defp open(:stdio), do: {0,1}
  defp open({:tcp,ip,port}), do:
    open({parse_ip(ip),port})
  defp open({{:ipv4,ip},port}) do
    sockaddr = Socket.sockaddr_common(2,4)<> <<port::16>> <> ip
    open({:sock,2,sockaddr})
  end
  defp open({{:ipv6,ip},port}) do
    sockaddr = Socket.sockaddr_common(30,16)<> <<port::16>> <> <<0::32,ip::binary,0::32>>
    open({:sock,30,sockaddr})
  end
  defp open({:unix,sockpath}) do
    pad = 8*(Socket.unix_path_max - byte_size(sockpath))
    sockaddr = Socket.sockaddr_common(1,byte_size(sockpath)) <> sockpath <> <<0::size(pad)>>
    open({:sock,1,sockaddr})
  end
  defp open({:sock,family,sockaddr}) do
    {:ok,socket}= Socket.socket(family,1,0)
    :ok = Socket.connect(socket,sockaddr)
    {socket,socket}
  end
end
