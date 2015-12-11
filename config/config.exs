use Mix.Config

config :logger,
  backends: [case Mix.env do
      :host-> NVim.Logger
      :debug_host-> NVim.DebugLogger
      _-> :console
  end],
  level: if(Mix.env == :debug_host, do: :debug, else: :info),
  handle_otp_reports: true,
  handle_sasl_reports: true

config :neovim,
  debug_logger_file: "nvim_debug",
  update_api_on_startup: true,
  link: if(Mix.env in [:host,:debug_host], 
          do: :stdio,
          else: {:tcp,"127.0.0.1",6666})
