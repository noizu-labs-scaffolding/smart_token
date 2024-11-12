defmodule SmartToken.SchemaBehaviour do
  # Return matching smart token or array of matching smart tokens
  @callback lookup_smart_token(token_a :: term, token_b :: term, context :: any, options :: any) :: {:ok, term} | {:error, term}

  # Save smart token using upsert, populate id field.
  @callback save_smart_token(term :: any, context :: any, options :: any) :: {:ok, term} | {:error, term}
end
