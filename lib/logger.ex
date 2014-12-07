defmodule NVim.Logger do
  use GenEvent

  def handle_event({level,_leader,{Logger,msg,_ts,_md}},state) do
    clean_msg = msg |> to_string |> String.split("\n") |> hd |> String.replace("\"","\\\"")
    NVim.vim_command ~s/echo "#{level}: #{clean_msg}"/
    {:ok,state}
  catch _, _ -> {:ok,state}
  end

  def handle_call({:configure,_opts},state), do:
    {:ok,:ok,state}
end
