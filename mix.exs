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
    [{:message_pack, "~> 0.1.4"},
     {:procket, github: "msantos/procket"}]
  end
end
