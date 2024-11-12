if Code.ensure_loaded?(Ecto) do
  store = Application.compile_env(:smart_token, :store)
  repo = Application.compile_env(:smart_token, :repo)

  if is_nil(store) and is_nil(repo) do
    raise SmartToken.Exception, """
    You must provide a repo to use the default schema or schema module in your config.exs.
    ```elixir
    config, :smart_token,
      repo: YourApp.Repo
    ```
    """
  end

  unless(store) do
    defmodule SmartToken.Schema.SmartToken do
      @behaviour SmartToken.SchemaBehaviour
      @repo repo
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key {:id, Ecto.UUID, autogenerate: true}
      schema "noizu_smart_tokens" do
        field :token_a, Ecto.UUID
        field :token_b, Ecto.UUID
        field :smart_token, SmartToken.Ecto.SerializedTerm
        timestamps(type: :utc_datetime_usec)
      end

      @defimpl SmartToken.SchemaBehaviour
      def get_smart_token(id, context, options)
      def get_smart_token(id, _, _) do
        with %{id: id, smart_token: token} <- apply(@repo, :get, [SmartToken.Schema.SmartToken, id]) do
          token = put_in(token, [Access.key(:identifier)], id)
          {:ok, token}
        else
          error -> error
        end
      end

      @defimpl SmartToken.SchemaBehaviour
      def lookup_smart_token(token_a, token_b, context, options)
      def lookup_smart_token(token_a, token_b, _, _) do
        with %{id: id, smart_token: token} <- apply(@repo, :get_by, [SmartToken.Schema.SmartToken, [token_a: token_a, token_b: token_b]]) do
          token = put_in(token, [Access.key(:identifier)], id)
          {:ok, token}
        else
          error -> error
        end
      end

      @defimpl SmartToken.SchemaBehaviour
      def save_smart_token(token, context, options)
      def save_smart_token(token, _, _) do
        record = %SmartToken.Schema.SmartToken{
          id: token.identifier,
          token_a: token.token_a,
          token_b: token.token_b,
          smart_token: token
        }
        with {:ok, %{id: id}} <- apply(@repo, :insert, [record, [on_conflict: [set: [id: record.id, token_a: record.token_a, token_b: record.token_b, smart_token: record.smart_token, updated_at: DateTime.utc_now() ]], conflict_target: :id]]) do
          token = put_in(token, [Access.key(:identifier)], id)
          {:ok, token}
        else
          error -> error
        end
      end

    end
  end
else
  store = Application.compile_env(:smart_token, :store)
  if is_nil(store) do
    raise SmartToken.Exception, """
    If ecto is not available you must provide an alternative schema object in your config.exs.
    The schema module must implement the SmartToken.SchemaBehaviour
    ```elixir
    config, :smart_token,
      schema: YourApp.CustomSmartTokenSchema # e.g. mnesia, redis, etc.
    ```
    """
  end
end
