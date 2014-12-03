use Mix.Config

config :logger,
  backends: [NVim.Logger],
  level: :debug,
  handle_otp_reports: true,
  handle_sasl_reports: true

config :neovim,
  link: if(Mix.env==:host, 
          do: :stdio,
          else: {:tcp,"127.0.0.1",6666})
