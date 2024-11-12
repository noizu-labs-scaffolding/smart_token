Supervisor.start_link([SmartToken.Repo], [strategy: :one_for_one, name: SmartToken.Supervisor])
ExUnit.start(capture_log: true)
