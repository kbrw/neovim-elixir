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
    Enum.filter(params,fn {k,_}-> k in [:eval] end)
  def autocmd_specs(params), do:
    Enum.filter(params,fn {k,_}-> k in [:group,:nested] end)
  def command_other_specs(params), do:
    Enum.filter(params,fn {k,_}-> k in [:buffer,:bar] end)
  def command_values_specs(params), do:
    Enum.filter(params,fn {k,_}-> k in [:range,:count,:bang,:register] end)
  def command_args_specs(params) do
    Enum.filter(params,fn {k,_}-> k in [:range,:count,:bang,:register,:eval] end)
  end

  def wrap_reply({status,reply,state},_,_) when status in [:ok,:error], do:
    {:reply,{status,reply},state}
  def wrap_reply(other,initstate,_), do:
    {:reply,{:ok,other},initstate}

  defp list_or_noarg([]), do: []
  defp list_or_noarg(args), do: [args]

  def sig_to_sigwhen({:when,_,[{name,_,params},guard]}), do: {name,params,guard}
  def sig_to_sigwhen({name,_,params}), do: {name,params,true}

  defmacro deffunc(signature, funcparams \\ [], [do: body]) do
    {name,params,guard} = sig_to_sigwhen(signature)
    eval_specs = eval_specs(funcparams)
    [state|params] = Enum.reverse(params)

    {eval_args,params} = Enum.split(params,length(eval_specs))
    eval_args = list_or_noarg(Enum.reverse(eval_args))

    nargs_args = [Enum.reverse(params)]

    call_args = Enum.concat([nargs_args,eval_args])
    name = Mix.Utils.camelize("#{name}")
    quote do
      @specs if(@specs[unquote(name)], do: @specs, else:
               Dict.put(@specs,unquote(name),%{
                  type: "function", 
                  name: unquote(name),
                  sync: unquote(if(funcparams[:async], do: 0,else: 1)),
                  opts: %{unquote_splicing(if eval_specs == [],do: [], 
                            else: [eval: "[#{eval_specs|>Dict.values|>Enum.join(",")}]"])}
                }))
      def handle_call({:function,unquote(name),unquote(call_args)},var!(nvim_from),unquote(state)=initialstate) when unquote(guard) do
        wrap_reply(unquote(body),initialstate,unquote(funcparams[:async] in [nil,false]))
      end
    end
  end

  defp wrap_spec_value(_,true), do: ""
  defp wrap_spec_value(:range,:default_all), do: "%"
  defp wrap_spec_value(:range,:default_line), do: ""
  defp wrap_spec_value(_,value), do: value

  defmacro defcommand(signature, funcparams \\ [], [do: body]) do
    {name,params,guard} = sig_to_sigwhen(signature)
    values_specs = command_values_specs(funcparams)
    eval_specs = eval_specs(funcparams)
    [state|params] = Enum.reverse(params)

    eval_indexes = for {{:eval,_},i}<-Enum.with_index(funcparams), do: i
    {special_eval_args,params} = Enum.split(params,length(values_specs) + length(eval_specs))
    special_eval_args = Enum.reverse(special_eval_args)
    eval_args = Enum.map(eval_indexes,&Enum.at(special_eval_args,&1))
    eval_args = list_or_noarg(eval_args)

    special_args = Enum.reduce(eval_indexes,special_eval_args,&List.delete_at(&2,&1))
    special_dict = Enum.zip(Dict.keys(values_specs),special_args)
    nvim_arg_order = [range: 0,count: 1,bang: 2,register: 3]
    special_args = special_dict |> Enum.sort_by(fn {k,_}->nvim_arg_order[k] end) |> Dict.values

    with_defaults = Enum.reverse(params)
    without_defaults = Enum.map(with_defaults, fn {:\\,_,[e,_]}->e; e->e end)
    defaults = Enum.map(with_defaults,fn {:\\,_,[_,default]}->default; _->nil end)
    nargs_args = list_or_noarg(without_defaults)

    call_args = Enum.concat([nargs_args,special_args,eval_args])
    default_call_args = Enum.concat([[quote do: _],special_args,eval_args])
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
                      if(eval_specs == [], do: [], else: [eval: "[#{eval_specs|>Dict.values|>Enum.join(",")}]"])
                    )}
                }))
      def handle_call({:command,unquote(name),unquote(call_args)},var!(nvim_from),unquote(state)=initialstate)  when unquote(guard)  do
        wrap_reply(unquote(body),initialstate,unquote(funcparams[:async] in [nil,false]))
      end
      if unquote(nargs_args !== []) do
        def handle_call({:command,unquote(name),unquote(default_call_args)=[nargs|other_args]},from,unquote(state)=initialstate)  when unquote(guard)  do
          nargs = nargs ++ Enum.slice(unquote(defaults),length(nargs)..-1)
          handle_call({:command,unquote(name),[nargs|other_args]},from,initialstate)
        end
      end
    end
  end

  defmacro defautocmd(signature, funcparams \\ [], [do: body]) do
    {name,params,guard} = sig_to_sigwhen(signature)
    eval_specs = eval_specs(funcparams)
    [state|params] = Enum.reverse(params)

    call_args = list_or_noarg(Enum.reverse(params))
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
                      if(eval_specs == [],do: [], else: [eval: "[#{eval_specs|>Dict.values|>Enum.join(",")}]"])
                    )}
                }))
      def handle_call({:autocmd,{unquote(name),unquote(pattern)},unquote(call_args)},var!(nvim_from),unquote(state)=initialstate) when unquote(guard) do
        wrap_reply(unquote(body),initialstate,unquote(funcparams[:async] in [nil,false]))
      end
    end
  end

end
