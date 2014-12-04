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
