defmodule NVim.Logger do
  use GenEvent

  def handle_event({level,_leader,{Logger,msg,_ts,_md}},:activated) do
    NVim.vim_command ~s/echo "#{level}: #{clean_msg msg}"/
    {:ok,:activated}
  end
  def handle_event({_,_,{Logger,["Application ","neovim"," started at "|_],_,_}},_), do: {:ok,:activated}
  def handle_event(_,state), do: {:ok,state}

  defp clean_msg(msg) do
    msg 
    |> to_string 
    |> String.split("\n")
    |> hd
    |> String.replace("\"","\\\"")
  end

  def handle_call({:configure,_opts},state), do: 
    {:ok,:ok,state}
end
