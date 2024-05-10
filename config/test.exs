import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :calori, CaloriWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "flZWl/X1Ep3QZ9s+jDwirqKRw5XxL+N2L5erQ5VM/tQxObO0NptcW5lPtpWdMOT1",
  server: false

# In test we don't send emails.
config :calori, Calori.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true
