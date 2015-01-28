defmodule NVim.Plugin do

  defmacro __using__(_) do
    quote do
      import NVim.Plugin
      import Supervisor.Spec
      use GenServer
      @before_compile NVim.Plugin
      @specs %{}

      def start_link(init), do: GenServer.start_link(__MODULE__,init, name: __MODULE__)
      def child_spec, do: worker(__MODULE__,[%{}])

      defoverridable [child_spec: 0]
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def nvim_specs, do: Dict.values(@specs)
    end
  end

  def eval_specs(params), do:
    Enum.filter(params,fn {k,_}-> not k in [:async,:range,:count,:bang,:register,:pattern,:buffer,:bar,:group,:nested] end)
  def command_values_specs(params), do:
    Enum.filter(params,fn {k,_}-> k in [:range,:count,:bang,:register] end)
  def command_other_specs(params), do:
    Enum.filter(params,fn {k,_}-> k in [:buffer,:bar] end)
  def autocmd_specs(params), do:
    Enum.filter(params,fn {k,_}-> k in [:group,:nested] end)

  def wrap_reply({status,reply,state},_,_) when status in [:ok,:error], do:
    {:reply,{status,reply},state}
  def wrap_reply(other,initstate,_), do:
    {:reply,{:ok,other},initstate}

  def params_to_eval(params) do
    map = params
    |> Enum.map(fn {k,v}->"'#{k}': #{v}" end)
    |> Enum.join(", ")
    "{#{map}}"
  end

  def sig_to_sigwhen({:when,_,[{name,_,params},guard]}), do: {name,params,guard}
  def sig_to_sigwhen({name,_,params}), do: {name,params,true}

  defmacro deffunc(signature, funcparams \\ [], [do: body]) do
    {name,params,guard} = sig_to_sigwhen(signature)
    [state|params] = Enum.reverse(params)
    eval_specs = eval_specs(funcparams)
    {eval_args,params} = if eval_specs == [] do 
      {[],params}
    else
      [eval|params] = params
      {[eval],params}
    end
    nargs_args = [Enum.reverse(params)]
    call_args = Enum.concat([nargs_args,eval_args])
    name = Mix.Utils.camelize("#{name}")
    quote do
      @specs if(@specs[unquote(name)], do: @specs, else:
               Dict.put(@specs,unquote(name),%{
                  type: "function", 
                  name: unquote(name),
                  sync: unquote(if(funcparams[:async], do: 0,else: 1)),
                  opts: %{unquote_splicing(if eval_specs == [],do: [], else: [eval: params_to_eval(eval_specs)])}
                }))
      def handle_call({:function,unquote(name),unquote(call_args)},var!(_from),unquote(state)=initialstate) when unquote(guard) do
        wrap_reply(unquote(body),initialstate,unquote(funcparams[:async] in [nil,false]))
      end
    end
  end

  def wrap_spec_value(_,true), do: ""
  def wrap_spec_value(:range,:default_all), do: "%"
  def wrap_spec_value(:range,:default_line), do: ""
  def wrap_spec_value(_,value), do: value

  defmacro defcommand(signature, funcparams \\ [], [do: body]) do
    {name,params,guard} = sig_to_sigwhen(signature)
    [state|params] = Enum.reverse(params)
    eval_specs = eval_specs(funcparams)
    {eval_args,params} = if eval_specs == [] do 
      {[],params}
    else
      [eval|params] = params
      {[eval],params}
    end
    values_specs = command_values_specs(funcparams)
    {special_args,params} = if values_specs == [] do
      {[],params}
    else
      {special,params} = Enum.split(params,length(values_specs))
      special_dict = Enum.zip(Dict.keys(values_specs),Enum.reverse(special))
      arg_order = [range: 0,count: 1,bang: 2,register: 3]
      special = special_dict |> Enum.sort_by(fn {k,_}->arg_order[k] end) |> Dict.values
      {special,params}
    end
    nargs_args = if params == [], do: [], else: [Enum.reverse(params)]
    call_args = Enum.concat([nargs_args,special_args,eval_args])
    name = Mix.Utils.camelize("#{name}")
    quote do
      @specs if(@specs[unquote(name)], do: @specs, else:
               Dict.put(@specs,unquote(name),%{
                  type: "command", 
                  name: unquote(name),
                  sync: unquote(if(funcparams[:async], do: 0,else: 1)),
                  opts: %{unquote_splicing(
                      if(nargs_args == [], do: [], else: [nargs: "*"]) ++
                      Enum.map(values_specs++command_other_specs(funcparams),fn {k,v}->{k,wrap_spec_value(k,v)} end) ++
                      if(eval_specs == [], do: [], else: [eval: params_to_eval(eval_specs)])
                    )}
                }))
      def handle_call({:command,unquote(name),unquote(call_args)},var!(from),unquote(state)=initialstate)  when unquote(guard)  do
        wrap_reply(unquote(body),initialstate,unquote(funcparams[:async] in [nil,false]))
      end
    end
  end

  defmacro defautocmd(signature, funcparams \\ [], [do: body]) do
    {name,params,guard} = sig_to_sigwhen(signature)
    [state|params] = Enum.reverse(params)
    eval_specs = eval_specs(funcparams)
    call_args = if eval_specs == [] do [] else params end
    name = Mix.Utils.camelize("#{name}")
    pattern = funcparams[:pattern] || "*"
    quote do
      @specs if(@specs[unquote(name)], do: @specs, else:
               Dict.put(@specs,unquote(name),%{
                  type: "autocmd", 
                  name: unquote(name),
                  sync: unquote(if(funcparams[:async], do: 0,else: 1)),
                  opts: %{unquote_splicing(
                      [pattern: pattern]++
                      Enum.map(autocmd_specs(funcparams),fn {k,v}->{k,wrap_spec_value(k,v)} end) ++
                      if(eval_specs == [],do: [], else: [eval: params_to_eval(eval_specs)])
                    )}
                }))
      def handle_call({:autocmd,{unquote(name),unquote(pattern)},unquote(call_args)},var!(from),unquote(state)=initialstate) when unquote(guard) do
        wrap_reply(unquote(body),initialstate,unquote(funcparams[:async] in [nil,false]))
      end
    end
  end

end
