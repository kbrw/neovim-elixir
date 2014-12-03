defmodule Neovim.Mixfile do
  use Mix.Project

  def project do
    [app: :neovim,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  def application do
    [applications: [:logger],
     mod: { Neovim.App, [] },
     env: []]
  end

  defp deps do
    [{:procket, github: "msantos/procket"},
     {:procket, github: "msantos/procket"}]
  end
end
