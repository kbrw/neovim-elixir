defmodule NVim.Host do
  require Logger
  def init_plugins, do: HashDict.new
  def ensure_plugin(path,plugins) do
    case plugins[path] do
      nil -> 
        modules = Code.compile_string(File.read!(path),path)
        {plugin,_} = Enum.find(modules,fn {mod,_}->
          function_exported?(mod,:nvim_specs,0)
        end)
        {:ok,_} = Supervisor.start_child NVim.Plugin.Sup, plugin.child_spec
        {plugin,Dict.put(plugins,path,plugin)}
      plugin -> {plugin,plugins}
    end
  end

  def specs(plugin), do: plugin.nvim_specs

  def handle(plugin,[type|name],args), do:
    GenServer.call(plugin,{:"#{type}",Enum.join(name),args})
end

defmodule NVim.Plugin.Sup do
  use Supervisor
  def start_link, do: Supervisor.start_link(__MODULE__,nil,name: __MODULE__)
  def init(_), do: supervise([], strategy: :one_for_one)
end
