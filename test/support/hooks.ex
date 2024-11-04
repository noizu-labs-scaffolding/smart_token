defmodule SmartTokenTest.Hooks do

  def  save_token(token, _context, _options) do
    cond do
      token.identifier ->
        all = :persistent_term.get(:smart_token_testdb, %{})
              |> put_in([Access.key(token.identifier)], token)
        :persistent_term.put(:smart_token_testdb, all)
        {:ok, token}
      :else ->
        token = put_in(token, [Access.key(:identifier)], System.monotonic_time())
        all = :persistent_term.get(:smart_token_testdb, %{})
              |> put_in([Access.key(token.identifier)], token)
        :persistent_term.put(:smart_token_testdb, all)
        {:ok, token}
    end
  end

  def get_token(token) do
    all = :persistent_term.get(:smart_token_testdb, %{})
    with token <- get_in(all, [Access.key(token.identifier)]),
         false <- is_nil(token) do
      {:ok, token}
    else
      _ -> {:error, :not_found}
    end
  end

  def get_by_token(token_a, token_b) do
    matches = :persistent_term.get(:smart_token_testdb, %{})
              |> Enum.filter(
                   fn
                     {_, token} -> token.token_a == token_a && token.token_b == token_b
                   end
                 )
              |> Enum.map(&elem(&1, 1))
    unless matches == [] do
      {:ok, matches}
    else
      {:error, :token_not_found}
    end
  end

end
