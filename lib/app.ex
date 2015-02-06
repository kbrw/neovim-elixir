defmodule NVim.App do
  use Application
  def start(_type, _args) do
    ## Make sure that the IO server of this application and all launched applications
    ## is a sink ignoring messages, to ensure that standard input/output will
    ## not be taken by running code and make the neovim host die
    io_sink = IOLeaderSink.start_link
    Process.group_leader(self,io_sink)
    Process.group_leader(Process.whereis(:application_controller),io_sink)

    NVim.App.Sup.start_link
  end

  defmodule Sup do
    use Supervisor

    def start_link, do: Supervisor.start_link(__MODULE__,[])

    def init([]) do
      supervise([
        worker(NVim.Link,[Application.get_env(:neovim,:link,:stdio)]),
        worker(NVim.Plugin.Sup,[]),
        worker(__MODULE__,[], function: :gen_api, restart: :temporary)
      ], strategy: :one_for_all)
    end

    def gen_api do
      if Application.get_env(:neovim,:update_api_on_startup,true), do:
        NVim.Api.from_instance
      :ignore
    end
  end
end

defmodule Sleeper do
  @moduledoc "when start as escript, just wait"
  def main(_), do: :timer.sleep(:infinity)
end

defmodule Mix.Tasks.Nvim.Attach do
  use Mix.Task

  def run([arg]) do
    Mix.Task.run "loadconfig", []
    if ?/ in '#{arg}' do
      :application.set_env(:neovim,:link,{:unix,arg}, persistent: true)
    else
      [_,ip,port] = Regex.run ~r/^\[?(.*)\]?:([0-9]+)$/, arg
      {port,_} = Integer.parse(port)
      :application.set_env(:neovim,:link,{:tcp,ip,port}, persistent: true)
    end
    Mix.Task.run "app.start", []
  end
  def run(_) do
    Mix.shell.info "usage : "
    Mix.shell.info "iex -S mix nvim.attach /path/to/unix/socket"
    Mix.shell.info "iex -S mix nvim.attach ip4:port"
    Mix.shell.info "iex -S mix nvim.attach ip6:port"
  end
end

defmodule IOLeaderSink do
  def handle(from,reply_as,{:put_chars,_,_}), do:
    send(from,{:io_reply,reply_as,:ok})
  def handle(from,reply_as,{:put_chars,_,_,_,_}), do:
    send(from,{:io_reply,reply_as,:ok})
  def handle(from,reply_as,{:get_until,_,_,_,_,_}), do:
    send(from,{:io_reply,reply_as,{:done,:eof,[]}})
  def handle(from,reply_as,{:get_chars,_,_,_}), do:
    send(from,{:io_reply,reply_as,:eof})
  def handle(from,reply_as,{:get_line,_,_}), do:
    send(from,{:io_reply,reply_as,:eof})
  def handle(from,reply_as,{:setopts,_}), do:
    send(from,{:io_reply,reply_as,:ok})
  def handle(from,reply_as,:getopts), do:
    send(from,{:io_reply,reply_as,[]})
  def handle(from,reply_as,{:requests,requests}), do:
    for(r<-requests, do: handle(from,reply_as,r))
  def handle(from,reply_as,_), do:
    send(from,{:io_reply,reply_as,{:error,:request}})
  def loop do
    receive do 
      {:io_request,from,reply_as,req}-> handle(from,reply_as,req)
      _->:ok 
    end; loop
  end
  def start_link, do: spawn_link(__MODULE__,:loop,[])
end
