defmodule NVim.App do
  use Application
  def start(_type, _args), do: 
    NVim.App.Sup.start_link

  defmodule Sup do
    use Supervisor

    def start_link, do: Supervisor.start_link(__MODULE__,[])

    def init([]) do
      supervise([
        worker(NVim.Link,[Application.get_env(:neovim,:link,:stdio)]),
        worker(NVim.Plugin.Sup,[]),
        worker(__MODULE__,[], function: :gen_api, restart: :temporary)
      ], strategy: :one_for_all)
    end

    def gen_api, do: (NVim.Api.from_instance; :ignore)
  end
end

defmodule Sleeper do
  @moduledoc "when start as escript, just wait"
  def main(_), do: :timer.sleep(:infinity)
end

defmodule Mix.Tasks.Nvim.Attach do
  use Mix.Task

  def run([arg]) do
    Mix.Task.run "loadconfig", []
    if ?/ in '#{arg}' do
      :application.set_env(:neovim,:link,{:unix,arg}, persistent: true)
    else
      [_,ip,port] = Regex.run ~r/^\[?(.*)\]?:([0-9]+)$/, arg
      {port,_} = Integer.parse(port)
      :application.set_env(:neovim,:link,{:tcp,ip,port}, persistent: true)
    end
    Mix.Task.run "app.start", []
  end
  def run(_) do
    Mix.shell.info "usage : "
    Mix.shell.info "iex -S mix nvim.attach /path/to/unix/socket"
    Mix.shell.info "iex -S mix nvim.attach ip4:port"
    Mix.shell.info "iex -S mix nvim.attach ip6:port"
  end
end

