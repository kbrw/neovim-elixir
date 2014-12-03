use Mix.Config

config :logger,
  backends: [Neovim.Logger],
  level: :debug,
  handle_otp_reports: true,
  handle_sasl_reports: true

config :neovim,
  link: if(Mix.env==:host, 
          do: :stdio,
          else: {:unix,"/var/folders/1m/8nt3hcj54wx0z4m7l6ht9jhc0000gq/T/nvimIULNE0/0"})
