if Code.ensure_loaded?(Ecto) do
  defmodule SmartToken.Ecto.SerializedTerm do
    @doc false
    def type, do: :string

    def equal?(a,b) do
      a == b
    end

    def cast(v) do
      {:ok, v}
    end

    @doc """
    Same as `cast/1` but raises `Ecto.CastError` on invalid arguments.
    """
    def cast!(v) do
      case cast(v) do
        {:ok, v} -> v
        _ -> raise ArgumentError, "Unsupported: #{inspect v}"
      end
    end

    def dump(nil) do
      {:ok, nil}
    end
    def dump(object) do
      with binary <- :erlang.term_to_binary(object),
           base64 <- binary && Base.encode64(binary) do
        {:ok, base64}
      else
        e -> {:error, e}
      end
    end

    def load(nil), do: {:ok, nil}
    def load(v) do
      with {:ok, raw} <- Base.decode64(v) do
        {:ok, :erlang.binary_to_term(raw)}
      else
        _ -> {:error, :not_valid_base64}
      end
    end

    def load!(value) do
      case load(value) do
        {:ok, v} -> v
        :error -> raise ArgumentError, "Invalid value received from database. Expected nil or base64 encoded :erlang.term_to_binary: #{inspect(value)}"
      end
    end
  end
end
