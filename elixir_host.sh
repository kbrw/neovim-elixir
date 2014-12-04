cd $(dirname $0)
MIX_ENV=host elixir --no-halt --name "$1@127.0.0.1" --erl "-noinput" -S mix
