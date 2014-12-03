Elixir host for NVim
======================

Bind an elixir application to a neovim instance accoding to the `Application.get_env(:neovim,:link)` config :

- `:stdio` : as a host plugin.  in neovim : `:let chan=rpcstart("./elixir_host.sh",["nodename"])`. Then you
  can connect to the attached elixir shell with `iex --name "toto@127.0.0.1" --remsh "nodename@127.0.0.1"`
- `{:tcp,"127.0.0.1",4444}` : to a running editor through a TCP socket
- `{:unix,"/path/to/sock.sock"}` : to a running editor through an unix domain socket

Execute `:echo $NVIM_LISTEN_ADDRESS` in your instance to find the current address of your instance.

## Talk from Elixir to Vim ##

The `NVim` module functions and docs are dynamically generated from the
msgpack functions available at `vim_get_api_info`.

So you can do for instance : 

```elixir
h NVim.vim_command
NVim.vim_command ~s/echo "toto"/
NVim.vim_del_current_line
```

## Talk from Vim to Elixir ##

You can call any elixir function from vim using rpcrequest, function
name is an anonymous function body, arguments are then applied to
this function. 

```
:let result = rpcrequest(chan,"a,b->a+b",3,2)
:echo result
5
:let result = rpcrequest(chan,"->3 + 3")
:echo result
6
```

## React to Vim events ##

All the message pack notifications are translated into GenEvent events
`NVim.Events` so you can easyly react to them in your plugin. For instance,
the following handler will log all the vim events.

```elixir
defmodule LogEvent do 
  use GenEvent
  require Logger
  def handle_event(ev,s) do
    Logger.info "event : #{inspect ev}"
    {:ok,s}
  end
end
GenEvent.add_handler NVim.Events, LogEvent, []
```

Then test it sending from event in vim : `:call rpcnotify(chan,"an_event","arg1",3)`

## Elixir logger to vim ##

The `NVim.Logger` logger backend take the first line of a log and `echo` it
to vim.
