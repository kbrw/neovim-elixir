defmodule NVim.Plugin do

  defmacro __using__(_) do
    quote do
      import NVim.Plugin
      import Supervisor.Spec
      use GenServer
      @before_compile NVim.Plugin
      @specs %{}

      def start_link, do: GenServer.start_link(__MODULE__,[], name: __MODULE__)
      def child_spec, do: worker(__MODULE__,[])
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def nvim_specs, do: Dict.values(@specs)
    end
  end

  def additionnal_params(params) do
    Enum.filter(params,fn {k,_}-> not k in [:async] end)
  end

  def wrap_reply({status,reply,state},_,_) when status in [:ok,:error], do:
    {:reply,{status,reply},state}
  def wrap_reply(other,initstate,true), do:
    {:reply,{:ok,other},initstate}
  def wrap_reply(other,_,false), do:
    {:reply,{:ok,nil},other}

  def params_to_eval(params) do
    map = params
    |> Enum.map(fn {k,v}->"'#{k}': #{v}" end)
    |> Enum.join(", ")
    "{#{map}}"
  end

  defmacro deffunc({name,_,params}, funcparams \\ [], [do: body]) do
    {params,[state]} = Enum.split(params,-1)
    eval_params = additionnal_params(funcparams)
    params = if eval_params == [] do [params] else
      {params,[eval]} = Enum.split(params,-1)
      [params,eval]
    end
    name = String.capitalize("#{name}")
    quote do
      @specs if(@specs[unquote(name)], do: @specs, else:
               Dict.put(@specs,unquote(name),%
                 {type: "function", 
                  name: unquote(name),
                  sync: unquote(if(funcparams[:async], do: 0,else: 1)),
                  opts: %{unquote_splicing(if eval_params == [] do [] else [eval: params_to_eval(eval_params)] end)}
                  }))
      def handle_call({:function,unquote(name),unquote(params)},var!(from),unquote(state)=initialstate) do
        wrap_reply(unquote(body),initialstate,unquote(funcparams[:async] in [nil,false]))
      end
    end
  end
end
