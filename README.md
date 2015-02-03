Elixir host for NVim
====================

# Write your Vim plugin in Elixir : Elixir Host for NVim #

Firstly, to replace your vim with nvim, not so hard :)

```
git clone https://github.com/neovim/neovim ; cd neovim ; sudo make install
cp -R ~/.vim ~/.nvim ; cp ~/.vimrc ~/.nvimrc
alias vim=nvim
```

Then you can either directly use [my own branch of `vim-elixir`](https://github.com/awetzel/vim-elixir/tree/nvim-rplugin) which includes the elixir host and a plugin for autocompletion, live elixir interpreter in vim and application execution in vim 

```
git clone -b nvim-rplugin https://github.com/awetzel/vim-elixir
cp -R vim-elixir/* ~/.nvim/
```

Or compile it manually with the next section and develop your own plugin.

## INSTALL ##

Compile the Elixir Host, then copy the vim-elixir-host directory to `~/.nvim` : 

```
mix deps.get
MIX_ENV=host mix escript.build
cp -R vim-elixir-host/* ~/.nvim/
# or with pathogen cp -R vim-elixir-host ~/.nvim/bundle/
```

That's it ! But actually because of a hack ! The folder contains
`autoload/remote/host.vim` which overrides the one from the
mainstream runtime to add 5 lines to accept Elixir plugins. This
is a hack before we integrate the elixir host into the mainstream
NVim project (need to open an issue and do lobbying).

## Write a vim Elixir plugin ##

Before going into a detail, let's see a basic usage example : add
Elixir autocompletion for module and functions, with documentation in
the preview window, in less than 40 LOC.

```
mkdir -p ~/.nvim/rplugin/elixir
vim ~/.nvim/rplugin/elixir/completion.ex
```

```elixir
defmodule AutoComplete do
  use NVim.Plugin

  deffunc elixir_complete("1",_,%{"line"=>line,"cursor"=>cursor},state), cursor: "col('.')", line: "getline('.')" do
    cursor = cursor - 1 # because we are in insert mode
    [tomatch] = Regex.run(~r"[\w\.:]*$",String.slice(line,0..cursor-1))
    cursor - String.length(tomatch)
  end
  deffunc elixir_complete(_,base,_,state), cursor: "col('.')", line: "getline('.')" do
    case (base |> to_char_list |> Enum.reverse |> IEx.Autocomplete.expand) do
      {:no,_,_}-> [base] # no expand
      {:yes,comp,[]}->["#{base}#{comp}"] #simple expand, no choices
      {:yes,_,alts}-> # multiple choices
        Enum.map(alts,fn comp->
          {base,comp} = {String.replace(base,~r"[^.]*$",""), to_string(comp)}
          case Regex.run(~r"^(.*)/([0-9]+)$",comp) do # first see if these choices are module or function
            [_,function,arity]-> # it is a function completion
              replace = base<>function
              module = if String.last(base) == ".", do: Module.concat([String.slice(base,0..-2)]), else: Kernel
              if (docs=Code.get_docs(module,:docs)) && (doc=List.keyfind(docs,{:"#{function}",elem(Integer.parse(arity),0)},0)) do
                 %{"word"=>replace,"kind"=> if(elem(doc,2)==:def, do: "f", else: "m"), "abbr"=>comp,"info"=>elem(doc,4)}
              else
                %{"word"=>replace,"abbr"=>comp}
              end
            nil-> # it is a module completion
              module = base<>comp
              case Code.get_docs(Module.concat([module]),:moduledoc) do
                {_,moduledoc} -> %{"word"=>module,"info"=>moduledoc}
                _ -> %{"word"=>module}
              end
          end
        end)
    end
  end

  defautocmd file_type(state), pattern: "elixir", async: true do
    {:ok,nil} = NVim.vim_command("filetype plugin on")
    {:ok,nil} = NVim.vim_command("set omnifunc=ElixirComplete")
    state
  end
end
```

And then open nvim and execute `:UpdateRemotePlugins` to update the plugin database. 

That's it, just open an elixir file and "CTRL-X CTRL-O" for completion. 

## Plugin architecture ##

But the integration allows much more things, lets look into
details : 

- A plugin is an elixir file defining modules in
  `RUNTIMEPATH/rplugin/elixir`, but only one module must implement
  the `nvim_specs` function, it is called the _plugin module_
- The _plugin module_ must implement `child_spec/0` returning the
  supervisor child specification started on the first plugin call.
- The supervision tree must launch in it a GenServer registered
  with the name of the _plugin module_, a vim query will trigger a
  genserver call `{:function|:autocmd|:command,methodname,args}`
  to this registered process.
- The _plugin module_ must implement `nvim_specs/0` returning the
  specification of available commands, functions, autocmd with
  their options, as describeb in nvim documentation, in order to
  define them on the vim side as rpc calls to the host plugin :
  (`UpdateRemotePlugins`).

The code is self explanatory, so you can look at `host.ex` where
you can see this architecture :

```elixir
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
    GenServer.call(plugin,{:"#{type}",compose_name(name),args})
```

## Main plugin module definition facilities ##

`Use NVim.plugin` provides facilities to define the previously described module : 

- `use NVim.plugin` :
  - define a GenServer (`use GenServer`) with a `start_link`
    function starting it registered with the _plugin module_ name.
  - define a default but overridable `child_spec` launching only
    this GenServer.
  - define at the end of the module the `nvim_specs` function returning `@specs`
  - import macros`deffunc`,`defcommand`,`defautocmd` which
    - adds a nvim specification to `@spec`
    - defines a `def handle_call` but rearranging parameters and
      wrapping response to make it easier to understand and makes
      its definition closer to the corresponding vim definition.

So in the end `deffunc|defcommand|defautocmd` are only `def
handle_call` so you can pattern match and add guards as you want
(see the example of the completion function above). You can add
`handle_info`, `handle_cast` or even additional `handle_call` if
needed.  You can customize the `child_spec` in order to launch
dependencies, with the only contraint that the new tree must
contains the _plugin module_ GenServer.

## Understand deffunc ##

Todo

## Understand defcommand ##

Todo

## Understand defautocmd ##

Todo

## Elixir logs are "echoed" to vim ##

The `NVim.Logger` logger backend take the first line of a log and `echo` it
to vim.

# Control a nvim instance from Elixir #

Connect to a running vim instance using : 

```
iex -S mix nvim.attach "127.0.0.1:7777"
iex -S mix nvim.attach "[::1]:7777"
iex -S mix nvim.attach "/path/to/unix/domain/sock"
```

The argument is where the socket of your nvim instance lies : to
find the current listening socket of your nvim instance, just
read the correct env variable :

```
"" in vim 
:echo $NVIM_LISTEN_ADDRESS
```

By default this socket is a unix domain socket in a random file,
but you can customize the address at launch (tcp or unix domain socket):

```
NVIM_LISTEN_ADDRESS="127.0.0.1:7777" nvim
NVIM_LISTEN_ADDRESS="/tmp/mysock" nvim
```

## Auto generated API ##

The module `NVim` is automatically generated when you attach to
vim using `vim_get_api_info`. 

```
{:ok,current_line} = NVim.vim_get_current_line
{:ok,current_column} = NVim.vim_eval "col('.')"
NVim.vim_command "echo 'coucou'"
```

The help is also automatically generated

```
h NVim.vim_del_current_line
```


