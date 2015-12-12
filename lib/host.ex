defmodule NVim.Host do
  def init_plugins, do: HashDict.new
  def ensure_plugin(path,plugins) do
    case plugins[path] do
      nil -> 
        plugin = case Path.extname(path) do
          ".ex"->
            modules = Code.compile_string(File.read!(path),path) |> Enum.map(&elem(&1,0))
            Enum.find(modules,&function_exported?(&1,:nvim_specs,0))
          ".ez"->
            app_version = path |> Path.basename |> Path.rootname
            app =  app_version |> String.replace(~r/-([0-9]+\.?)+/,"") |> String.to_atom
            Code.append_path("#{path}/#{app_version}/ebin")
            res = Application.ensure_all_started(app)
            {:ok,modules} = :application.get_key(app,:modules)
            Enum.each(modules,&Code.ensure_loaded/1)
            Application.get_env(app,:nvim_plugin) || (
              {:ok,modules} = :application.get_key(app,:modules)
              Enum.find(modules,&function_exported?(&1,:nvim_specs,0)))
        end
        {:ok,_} = Supervisor.start_child NVim.Plugin.Sup, plugin.child_spec
        {plugin,Dict.put(plugins,path,plugin)}
      plugin -> {plugin,plugins}
    end
  end

  def specs(plugin), do: plugin.nvim_specs

  def compose_name([simple_name]), do: simple_name
  def compose_name(composed_name), do: List.to_tuple(composed_name)
  def handle(plugin,[type|name],args) do
    GenServer.call(plugin,{:"#{type}",compose_name(name),args}, :infinity)
  end
end

defmodule NVim.Plugin.Sup do
  use Supervisor
  def start_link, do: Supervisor.start_link(__MODULE__,nil,name: __MODULE__)
  def init(_), do: supervise([], strategy: :one_for_one)
end
