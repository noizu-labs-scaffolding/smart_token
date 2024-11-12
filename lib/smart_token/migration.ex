if Code.ensure_loaded?(Ecto) do
  defmodule SmartToken.Migration do
    use Ecto.Migration

    def up(1) do
      create table(:noizu_smart_tokens, primary_key: false) do
        add :id, :uuid, primary_key: true, autogenerate: true
        add :token_a, :uuid, null: false
        add :token_b, :uuid, null: false
        add :smart_token, :text
        timestamps(type: :utc_datetime_usec)
      end
      create index(:noizu_smart_tokens, [:token_a, :token_b], unique: true)
    end

    def down(1) do
      drop index(:noizu_smart_tokens, [:token_a, :token_b], unique: true)
      drop table(:noizu_smart_tokens)
    end
  end
end
