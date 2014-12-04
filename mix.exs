defmodule NVim.Mixfile do
  use Mix.Project

  def project do
    [app: :neovim,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  def application do
    [applications: [:logger],
     mod: { NVim.App, [] },
     env: []]
  end

  defp deps do
    [{:message_pack, github: "awetzel/msgpack-elixir", branch: "unpack_map_as_map"},
     {:procket, github: "msantos/procket"}]
  end
end
