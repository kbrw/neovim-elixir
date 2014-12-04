defmodule Mix.Tasks.Neovim.Host do
  use Mix.Task

  def run(_) do
    if Code.ensure_loaded?(Logger), do: Logger.App.stop()
    :application.set_env(:logger,:backends,[NVim.Logger], persistent: true)
    :application.set_env(:logger,:level,:debug, persistent: true)
    :application.set_env(:logger,:handle_otp_reports,true, persistent: true)
    :application.set_env(:logger,:handle_sasl_reports,true, persistent: true)
    :application.set_env(:neovim,:link,:stdio, persistent: true)
    case Application.ensure_all_started(:neovim,:permanent) do
      {:ok, _} -> :timer.sleep(:infinity)
      {:error, {app, reason}} -> 
          Mix.raise "Could not start application #{app}: " <>
            Application.format_error(reason)
    end
    
  end
end

defmodule Mix.Tasks.Neovim.WrapMsgpack do
  use Mix.Task

  def run(_) do
    wrapper = Path.wildcard("deps/message_pack/lib/**/*.ex")
    |> Enum.map(&File.read!/1)
    |> Enum.join("\n")
    wrapper = """
    defmodule NVimWrap do
    alias NVimWrap.MessagePack, as: MessagePack
    alias NVimWrap.MessagePack.Ext, as: MessagePack.Ext
    alias NVimWrap.MessagePack.Packer, as: MessagePack.Packer
    alias NVimWrap.MessagePack.Unpacker, as: MessagePack.Unpacker

    """<>wrapper<>"\nend"
    File.write("lib/msgpack_wrapper.ex")
  end
end
