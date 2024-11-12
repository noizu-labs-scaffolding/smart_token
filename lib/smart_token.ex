defmodule SmartToken.Exception do
  defexception message: "Invalid Token"
end

defmodule SmartToken do
  alias Noizu.EntityReference.Protocol, as: NoizuERP
  @vsn 1.0
  @schema (cond do
    x = Application.compile_env(:smart_token, :store) -> x
    Application.compile_env(:smart_token, :repo) -> SmartToken.Schema.SmartToken
    :else ->
      raise SmartToken.Exception, """
      You must set a schema module (adhering to SmartToken.SchemaBehaviour or ecto Repo in your config.
      ```elixir
      config, :smart_token,
        store: YourApp.Repo
      ```
      """
  end)

  @type t :: %__MODULE__{
    identifier: integer(),
    token_a: bitstring() | :generate,
    token_b: bitstring() | :generate,
    type: term(),
    resource: term(),
    scope: term(),
    active: boolean(),
    state: term(),
    context: term(),
    owner: term(),
    validity_period: term(),
    permissions: term(),
    extended_info: term(),
    access_history: term(),
    template: term(),
    kind: term()
  }

  defstruct [
    identifier: nil,
    token_a: :generate,
    token_b: :generate,
    type: nil,
    resource: nil,
    scope: nil,
    active: true,
    state: nil,
    context: nil,
    owner: nil,
    validity_period: nil,
    permissions: nil,
    extended_info: nil,
    access_history: nil,
    template: nil,
    kind: __MODULE__,
    vsn: @vsn
  ]

  # Time Periods
  @period_three_days {:unbound, {:relative, [{:day, 3}]}}
  #@period_fifteen_days {:unbound, {:relative, [{:day, 15}]}}

  @default_settings %{
    active: true,
    type: :generic,
    token_a: :generate,
    token_b: :generate,
    resource: {:bind, :recipient},
    state: :enabled,
    owner: :system,
    validity_period: :nil,
    permissions: :unrestricted,
    extended_info: :nil,
    scope: :nil,
    context: {:bind, :recipient}
  }


  #-------------------------------------
  # account_verification_token/1
  #-------------------------------------
  @doc """
  Create a new account verification token.
  """
  def account_verification_token(options \\ nil) do
    %{
      resource: {:bind, :recipient},
      context: {:bind, :recipient},
      scope: {:account_info, :verification},
      validity_period: @period_three_days,
      extended_info: %{single_use: true}
    }
    |> Map.merge(options || %{})
    |> put_in([:type], :account_verification)
    |> new()
  end


  def single_use(%__MODULE__{} = this) do
    extended_info = (this.extended_info || %{})
                    |> Map.delete(:multi_use)
                    |> Map.delete(:limit)
                    |> Map.put(:single_use, true)
    this
    |> put_in([Access.key(:extended_info)], extended_info)
  end

  def multi_use(%__MODULE__{} = this, limit) do
    extended_info = (this.extended_info || %{})
                    |> Map.delete(:single_use)
                    |> Map.put(:multi_use, true)
                    |> Map.put(:limit, limit)
    this
    |> put_in([Access.key(:extended_info)], extended_info)
  end

  def unlimited_use(%__MODULE__{} = this) do
    extended_info = (this.extended_info || %{})
                    |> Map.delete(:single_use)
                    |> Map.delete(:multi_use)
                    |> Map.delete(:limit)
                    |> Map.put(:unlimited_use, true)
    this
    |> put_in([Access.key(:extended_info)], extended_info)
  end


  @doc """
  Add a validity period to the token
      - from_period: `:unbound | {:relative, [{period, count}]} | {:fixed, time}`
      - to_period: `:unbound | {:relative, [{period, count}]} | {:fixed, time}`

  """
  def validity_period(%__MODULE__{} = this, from_period, to_period) do
    this
    |> put_in([Access.key(:validity_period)], {from_period, to_period})
  end

  @doc """
  Add ip whitelist entry(ies)
  """
  def ip_whitelist(%__MODULE__{} = this, cidr) when is_tuple(cidr) or is_bitstring(cidr) do
    this
    |> update_in([Access.key(:extended_info), :ip_whitelist], & (&1 || []) ++ [cidr])
  end
  def ip_whitelist(%__MODULE__{} = this, cidr) when is_list(cidr) do
    this
    |> update_in([Access.key(:extended_info), :ip_whitelist], & (&1 || []) ++ [cidr])
  end

  @doc """
  Add session key,value constraint
  """
  def session_value(%__MODULE__{} = this, key, value) do
    this
    |> update_in([Access.key(:extended_info), :session_values], & [{key, value} | (&1 || [])])
  end


  #-------------------------------------
  # new/1
  #-------------------------------------
  @doc """
  Create a new token with the given settings.
  """
  def new(settings \\ nil)
  def new(settings) do
    settings = Map.merge(@default_settings, settings || %{})
    %__MODULE__{
      active: settings.active,
      type: settings.type,
      token_a: settings.token_a,
      token_b: settings.token_b,
      resource: settings.resource,
      scope: settings.scope,
      state: settings.state,
      context: settings.context,
      owner: settings.owner,
      validity_period: settings.validity_period,
      permissions: settings.permissions,
      extended_info: settings.extended_info,
      #access_history: term(),
      #template: term(),
    }
  end

  #-------------------------------------
  # authorize!/4
  #-------------------------------------
  def authorize!(token_key, conn, context, options \\ %{})
  def authorize!(token_key, conn, context, options) when is_bitstring(token_key) do
    with {token_a, token_b} <- String.split_at(token_key, div(String.length(token_key),2)),
         {:ok, token_a} <- ShortUUID.decode(token_a),
         {:ok, token_b} <- ShortUUID.decode(token_b),
         {:ok, token} <- apply(@schema, :lookup_smart_token, [token_a, token_b, context, options]) do
      case validate(token, conn, context, options) do
        {:ok, token} ->
          update = record_valid_access!(token, conn, options)
          {:ok, update}
        {:error, error} ->
          token = record_invalid_access!(token, error, conn, options)
          {:error, error ++ [token: token]}
      end

    end

  end



  #---------------------------
  # encoded_key
  #---------------------------
  def encoded_key(%__MODULE__{} = this) do
    with {:ok, _} <- UUID.info(this.token_a),
         {:ok, _} <- UUID.info(this.token_b),
         {:ok, token_a} <- ShortUUID.encode(this.token_a),
         {:ok, token_b} <- ShortUUID.encode(this.token_b) do
      token_a <> token_b
    else
      error -> {:error, {:encoded_key, error}}
    end
  end


  #-------------------------------------
  # bind!/3
  #-------------------------------------
  def bind!(%__MODULE__{} = token, bindings, context, options \\ nil) do
    with {:ok, token} <- bind(token, bindings, options),
         {:ok, token} <- apply(@schema, :save_smart_token, [token, context, options]) do
      token
    else
      error -> raise SmartToken.Exception, "Bind! failure: #{inspect error}"
    end
  end

  #---------------------------
  # bind/3
  #---------------------------
  def bind(%__MODULE__{} = this, bindings, options) do


    with {:ok, token_a} <- bind_token(this.token_a, bindings),
         {:ok, token_b} <- bind_token(this.token_b, bindings),
         {:ok, resource} <- bind_ref(this.resource, bindings),
         {:ok, context} <- bind_ref(this.context, bindings),
         {:ok, owner} <- bind_ref(this.owner, bindings),
         {:ok, validity_period} <- bind_period(this, bindings, options) do


      this = %__MODULE__{this|
        token_a: token_a,
        token_b: token_b,
        resource: resource,
        context: context,
        owner: owner,
        validity_period: validity_period,
        access_history: %{history: [], count: 0},
        template: this
      }
      {:ok, this}

    end



  end

  #---------------------------
  # bind_token/2
  #---------------------------
  @spec bind_token(term, map) :: bitstring()
  defp bind_token(token, bindings)
  defp bind_token(:generate, _bindings) do
    {:ok, UUID.uuid5(:oid, "#{__MODULE__}.token@#{System.os_time(:microsecond)}#{System.monotonic_time()}")}
  end
  defp bind_token(token, _bindings), do: {:ok, token}


  #---------------------------
  # bind_ref/2
  #---------------------------
  def bind_ref(ref, bindings) do
    case ref do
      {:bind, path} when is_list(path) ->
        get_in(bindings, path)
        |> NoizuERP.ref()
      {:bind, field} ->
        get_in(bindings, [field])
        |> NoizuERP.ref()
      _ -> {:ok, ref}
    end
  end


  #---------------------------
  # bind_period/3
  #---------------------------
  defp bind_period(%__MODULE__{} = this, _bindings, options) do
    current_time = options[:current_time] || DateTime.utc_now()
    case this.validity_period do
      nil -> {:ok,  nil}
      {lv, rv} ->
        lv = case lv do
          :unbound -> :unbound
          {:relative, shift} -> shift_time(current_time, shift)
          {:fixed, time} -> time
        end
        rv = case rv do
          :unbound -> :unbound
          {:relative, shift} -> shift_time(current_time, shift)
          {:fixed, time} -> time
        end
        {:ok, {lv, rv}}
    end
  end

  defp shift_time(current, shift) do
    patch = %{
      year: :years,
      month: :months,
      week: :weeks,
      day: :days,
      hour: :hours,
      minute: :minutes,
      second: :seconds,
      microsecond: :microseconds
    }
    patched_shift = Enum.map(shift,
      fn
        {p, _} = x when p in [:year, :month, :week, :day, :hour, :minute, :second, :microsecond] -> x
        {p, v} when p in [:years, :months, :weeks, :days, :hours, :minutes, :seconds, :microseconds] ->
          {patch[p],v}
        x -> x # error
      end
    )
    DateTime.shift(current, patched_shift)
  end


  #---------------------------
  # validate/4
  #---------------------------
  def validate(%__MODULE__{} = this, conn, _context, options) do
    #this = entity!(this)
    checks = [
               {:period, validate_period(this, options)},
               {:access_count, validate_access_count(this)},
               {:remote_ip, validate_remote_ip(this, conn)},
               {:session, validate_session_values(this, conn)},
             ] |> Enum.reject(
                    fn
                      {_,:valid} -> true
                      _ -> false
                    end
                  )
    unless checks == [] do
      {:error, checks}
    else
      {:ok, this}
    end
  end


  #-------------------------------------
  # validate/4
  #-------------------------------------
  def validate(nil, _conn, _context, _options) do
    {:error, :invalid}
  end

  def validate([], _conn, _context, _options) do
    {:error, :invalid}
  end

  def validate([h|t], conn, context, options) do
    case validate(h, conn, context, options) do
      {:ok, v} -> {:ok, v}
      _ -> validate(t, conn, context, options)
    end
  end

  #---------------------------
  # validate_period/2
  #---------------------------
  def validate_period(this, options) do
    current_time = options[:current_time] || DateTime.utc_now()
    case this.validity_period do
      nil -> :valid
      :unbound -> :valid
      {l_bound, r_bound} ->
        cond do
          l_bound != :unbound && DateTime.compare(current_time, l_bound) == :lt -> {:error, :lt_range}
          r_bound != :unbound && DateTime.compare(current_time, r_bound) == :gt -> {:error, :gt_range}
          true -> :valid
        end
    end
  end

  #---------------------------
  # access_count/1
  #---------------------------
  def access_count(%__MODULE__{} = this) do
    this.access_history.count
  end

  #---------------------------
  # validate_access_count/1
  #---------------------------
  def validate_access_count(%__MODULE__{} = this) do
    case this.extended_info do
      %{single_use: true} ->
        # confirm first valid check
        if access_count(this) == 0 do
          :valid
        else
          {:error, :single_use_exceeded}
        end

      %{multi_use: true, limit: limit} ->
        if access_count(this) < limit do
          :valid
        else
          {:error, :multi_use_exceeded}
        end
      %{unlimited_use: true} -> :valid
      _ -> {:error, :invalid_access_constraint}
    end
  end

  def validate_remote_ip(%__MODULE__{} = this, conn) do
    with %{ip_whitelist: ip_whitelist} <- this.extended_info do
      ip_whitelist = is_list(ip_whitelist) && ip_whitelist || [ip_whitelist]
      Enum.find_value(
        ip_whitelist,
        {:error, {:ip_not_in_white_list, conn.remote_ip}},
        fn
          cidr when is_tuple(cidr) ->
            if conn.remote_ip do
              if InetCidr.contains?(cidr, conn.remote_ip) do
                :valid
              end
            end
          cidr when is_bitstring(cidr) ->
            if conn.remote_ip do
              with {:ok, cidr} <- InetCidr.parse_cidr(cidr) do
                InetCidr.contains?(cidr, conn.remote_ip) && :valid || nil
              end
            end
        end
      )
    else
      _ -> :valid
    end
  end

  def validate_session_values(%__MODULE__{} = this, conn) do
    with %{session_values: values} <- this.extended_info do
      errors = Enum.map(values, fn {key, value} ->
        case Plug.Conn.get_session(conn, key) do
          ^value -> nil
          _ -> key
        end
      end) |> Enum.reject(&is_nil/1)
      if errors == [] do
        :valid
      else
        {:error, {:values, errors}}
      end
    else
      _ -> :valid
    end
  end

  #---------------------------
  # record_valid_access!/2
  #---------------------------
  def record_valid_access!(%__MODULE__{} = this, conn, options) do
    current_time = options[:current_time] || DateTime.utc_now()
    ip = conn && conn.remote_ip && conn.remote_ip |> Tuple.to_list |> Enum.join(".")
    entry = %{time: current_time, ip: ip,  type: :valid}
    record_access!(this, entry, options)
  end

  #---------------------------
  # record_access!/3
  #---------------------------
  def record_access!(%__MODULE__{} = this, entry, options \\ nil) do
    context = Noizu.Context.admin()
    this = this
           |> update_in([Access.key(:access_history), :count], &((&1 || 0) + 1))
           |> update_in([Access.key(:access_history), :history], &((&1 || []) ++ [entry]))
    with {:ok, update} <- apply(@schema, :save_smart_token, [this, context, options]) do
      update
    else
      error -> raise SmartToken.Exception, "Record Access! failure: #{inspect error}"
    end

  end

  #---------------------------
  # record_invalid_access/2
  #---------------------------
  def record_invalid_access!(tokens, conn, options) when is_list(tokens) do
    current_time = options[:current_time] || DateTime.utc_now()
    ip = conn && conn.remote_ip && conn.remote_ip |> Tuple.to_list |> Enum.join(".")
    entry = %{time: current_time, ip: ip,  type: {:error, :check_mismatch}}
    Enum.map(tokens, fn(token) ->
      # TODO deal with active flag if it needs to be changed. @PRI-2
      #token = put_in(token, [Access.key(:active)], false)
      record_access!(token, entry, options)
    end)
  end

  def record_invalid_access!(%__MODULE{} = this, error, conn, options) do
    current_time = options[:current_time] || DateTime.utc_now()
    ip = conn.remote_ip |> Tuple.to_list |> Enum.join(".")
    entry = %{time: current_time, ip: ip,  type: error}
    record_access!(this, entry, options)
  end

end
