defmodule NVim.Api do
  @moduledoc """
    Auto generate the NVim module with functions extracted from the spec
    available either globally using `nvim --api-info` or once an instance is
    attached with the `vim_get_api_info` internal cmd.
  """

  def from_cmd do
    case System.cmd("nvim",["--api-info"]) do
      {res,0} -> 
        {:ok,spec} = MessagePack.unpack res
        generate_neovim(spec)
      _ -> :ok
    end
  end

  def from_instance do
    {:ok,[_,spec]} = GenServer.call NVim.Link, {"vim_get_api_info",[]}
    generate_neovim(spec)
  end

  def generate_neovim(%{"functions"=>fns,"types"=>types}) do
    defmodule Elixir.NVim do
      Enum.each fns, fn %{"name"=>name,"parameters"=>params}=func->
        fnparams = for [_type,pname]<-params,do: quote(do: var!(unquote({:"#{pname}",[],Elixir})))
        @doc """
          Parameters : #{inspect params}

          Return : #{inspect func["return_type"]}

          This function can #{if func["can_fail"]!=true, do: "not "}fail

          This function can #{if func["deferred"]!=true, do: "not "}be deferred
        """
        Module.eval_quoted(NVim, quote do
          def unquote(:"#{name}")(unquote_splicing(fnparams)) do
            GenServer.call NVim.Link, {unquote("#{name}"),unquote(fnparams)}
          catch
            :exit,{:timeout,_}-> {:error,"#{unquote(name)} timeout"}
          end
        end)
      end
    end
    Enum.each types, fn {name,%{"id"=>_id}}->
      defmodule Module.concat(["Elixir","NVim",name]) do
        defstruct content: ""
      end
    end
    defmodule Elixir.NVim.Ext do
      use MessagePack.Ext.Behaviour
      Enum.each types, fn {name,%{"id"=>id}}->
        Module.eval_quoted(NVim.Ext, quote do
          def pack(%unquote(Module.concat(["NVim",name])){content: bin}), do:
            {:ok, {unquote(id),bin}}
        end)
      end
      Enum.each types, fn {name,%{"id"=>id}}->
        Module.eval_quoted(NVim.Ext, quote do
          def unpack(unquote(id),bin), do:
            {:ok, %unquote(Module.concat(["NVim",name])){content: bin}}
        end)
      end
    end
  end
end

NVim.Api.from_cmd
