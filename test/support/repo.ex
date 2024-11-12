defmodule SmartToken.Repo do
  use Ecto.Repo,
      otp_app: :smart_token,
      adapter: Ecto.Adapters.Postgres
end
