defmodule Mix.Tasks.Compile.Msgpackwrapper do
  @shortdoc "Compiles message pack wrapper"
  def run(_) do
    wrapper = Path.wildcard("deps/message_pack/lib/**/*.ex")
    |> Enum.map(&File.read!/1)
    |> Enum.join("\n")
    wrapper = """
    defmodule NVimWrap do
    alias NVimWrap.MessagePack, as: MessagePack

    """<>wrapper<>"\nend"
    File.write("lib/msgpack_wrapper.ex",wrapper)
  end
end

defmodule NVim.Mixfile do
  use Mix.Project

  def project do
    [app: :neovim,
     version: "0.0.1",
     elixir: "~> 1.0",
     compilers: [:msgpackwrapper, :elixir, :app],
     deps: deps(Mix.env)]
  end

  def application do
    [applications: [:logger],
     mod: { NVim.App, [] },
     env: []]
  end

  defp deps(:archive), do: []
  defp deps(_) do
    [{:message_pack, github: "awetzel/msgpack-elixir", branch: "unpack_map_as_map"},
     {:procket, github: "msantos/procket"}]
  end
end
