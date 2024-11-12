import Config
config :smart_token, :ecto_repos, [SmartToken.Repo]

config :smart_token, SmartToken.Repo,
       username: "smart_token",
       password: "smart_token_1234",
       hostname: "127.0.0.1",
       port: 5550,
       database: "smart_token_test#{System.get_env("MIX_TEST_PARTITION")}",
       pool: Ecto.Adapters.SQL.Sandbox,
       pool_size: System.schedulers_online() * 2,
       migration_primary_key: [name: :id, type: :uuid]

config :smart_token,
  repo: SmartToken.Repo
