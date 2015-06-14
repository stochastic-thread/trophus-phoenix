use Mix.Config

# In this file, we keep production configuration that
# you likely want to automate and keep it away from
# your version control system.
config :hello_phoenix, HelloPhoenix.Endpoint,
  secret_key_base: "RsieqYq5+ENldo51eOxftSHZUMsRUII3fBmpx/b5hc6Y/vdABg3rqt2WMis+dnpJ"

# Configure your database
config :hello_phoenix, HelloPhoenix.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "hello_phoenix_prod",
  size: 20 # The amount of database connections in the pool
