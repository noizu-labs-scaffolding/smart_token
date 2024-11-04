defmodule SmartToken.Exception do
  defexception message: "Invalid Token"
end

defmodule SmartToken.InvalidHandler do
  def save_token(_token, _context, _options) do
    raise  SmartToken.Exception, "Missing save_token hook: add config :smart_token, hooks: [save_token: &provider/3] to your config.exs"
  end
  def get_token(_token) do
    raise  SmartToken.Exception, "Missing save_token hook: add config :smart_token, hooks: [get_token: &provider/1] to your config.exs"
  end
  def get_by_token(_token_a,_token_b) do
    raise  SmartToken.Exception, "Missing save_token hook: add config :smart_token, hooks: [get_by_token: &provider/2] to your config.exs"
  end

end

defmodule SmartToken do
  alias Noizu.EntityReference.Protocol, as: NoizuERP
  @vsn 1.0

  handlers = Application.compile_env(:smart_token, :hooks)
  @handler %{
    get_token: handlers[:get_token] || &SmartToken.InvalidHandler.get_token/1,
    get_by_token: handlers[:get_by_token] ||  &SmartToken.InvalidHandler.get_by_token/2,
    save_token: handlers[:save_token] ||  &SmartToken.InvalidHandler.save_token/3
  }

  @handler[:get_token] || raise SmartToken.Exception, "Missing get_by_token hook: add config :smart_token, hooks: [get_token: fun/1] to your config.exs"
  @handler[:get_by_token] || raise SmartToken.Exception, "Missing get_by_token hook: add config :smart_token, hooks: [get_by_token: fun/1] to your config.exs"
  @handler[:save_token] || raise SmartToken.Exception, "Missing save_token hook: add config :smart_token, hooks: [save_token: fun/2] to your config.exs"

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
         {:ok, matches} <- @handler[:get_by_token].(token_a, token_b),
         matches <- Enum.filter(matches, fn(m) -> m.active end),
         true <- matches != [] || {:error, :no_active_matches} do
      case validate(matches, conn, context, options) do
        {:ok, token} ->

          update = record_valid_access!(token, conn, options)
          {:ok, update}
        {:error, error} ->
          record_invalid_access!(matches, conn, options)
          {:error, error}
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
         {:ok, token} <- @handler[:save_token].(token, context, options) do
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
  def validate(%__MODULE__{} = this, _conn, _context, options) do
    #this = entity!(this)

    p_c = validate_period(this, options)
    a_c = validate_access_count(this)

    cond do
      p_c == :valid && a_c == :valid -> {:ok, this}
      true -> {:error, {{:period, p_c}, {:access_count, a_c}}}
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
    this = this
           |> update_in([Access.key(:access_history), :count], &((&1 || 0) + 1))
           |> update_in([Access.key(:access_history), :history], &((&1 || []) ++ [entry]))

    with {:ok, update} <- @handler[:save_token].(this, Noizu.Context.admin(), options) do
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

  def record_invalid_access!(%__MODULE{} = this, conn, options) do
    current_time = options[:current_time] || DateTime.utc_now()
    ip = conn.remote_ip |> Tuple.to_list |> Enum.join(".")
    entry = %{time: current_time, ip: ip,  type: {:error, :check_mismatch}}
    record_access!(this, entry, options)
  end

end
