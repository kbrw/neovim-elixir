use Mix.Config

config :logger,
  backends: [if(Mix.env==:host, do: NVim.Logger, else: Logger.Backends.Console)],
  level: :debug,
  handle_otp_reports: true,
  handle_sasl_reports: true

config :neovim,
  update_api_on_startup: true,
  link: if(Mix.env==:host, 
          do: :stdio,
          else: {:tcp,"127.0.0.1",6666})
