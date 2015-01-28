defmodule NVim.Mixfile do
  use Mix.Project

  def project do
    [app: :neovim,
     version: "0.1.0",
     consolidate_protocols: false,
     elixir: "~> 1.0",
     escript: escript,
     deps: deps]
  end

  def application do
    [applications: [:logger,:mix,:eex,:ex_unit,:iex,:procket,:message_pack],
     mod: { NVim.App, [] },
     env: [update_api_on_startup: true]]
  end

  defp deps do
    [{:message_pack, github: "awetzel/msgpack-elixir", branch: "unpack_map_as_map"},
     {:procket, github: "msantos/procket"}]
  end

  defp escript, do: [
    emu_args: "-noinput",
    path: "vim-elixir-host/tools/nvim_elixir_host",
    main_module: Sleeper
  ]
  
end


