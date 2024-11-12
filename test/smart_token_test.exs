defmodule SmartTokenTest do
  use ExUnit.Case

  doctest SmartToken

  @context Noizu.Context.admin()
  @conn_stub %Plug.Conn{remote_ip: {127, 0, 0, 1}, private: %{plug_session: %{"henry" => 5}}}

  @tag :smart_token
  test "Account Verification Create & Redeem" do
    user_ref = {:ref, SmartTokenTest.User, 1234}
    binding = %{recipient: user_ref}
    smart_token = SmartToken.account_verification_token(%{}) |> SmartToken.bind!(binding, @context, %{})

    encoded_link = SmartToken.encoded_key(smart_token)

    assert smart_token.access_history.count == 0
    assert smart_token.context == user_ref
    assert smart_token.extended_info[:single_use] == true
    assert smart_token.resource == user_ref
    assert smart_token.scope == {:account_info, :verification}
    assert smart_token.state == :enabled
    assert smart_token.type == :account_verification
    assert smart_token.permissions == :unrestricted
    {attempt, smart_token} = SmartToken.authorize!(encoded_link, @conn_stub, @context)
    assert attempt == :ok
    assert smart_token.resource == user_ref
  end




  @tag :smart_token
  test "Account Verification - IP In WhiteList" do
    user_ref = {:ref, SmartTokenTest.User, 1234}
    bindings = %{recipient: user_ref}
    smart_token = SmartToken.account_verification_token(%{})
                  |> SmartToken.ip_whitelist("127.0.0.1/32")
                  |> SmartToken.bind!(bindings, @context, %{})
    encoded_link = SmartToken.encoded_key(smart_token)

    {attempt, token} = SmartToken.authorize!(encoded_link, @conn_stub, @context)
    assert attempt == :ok
    assert smart_token.resource == user_ref
  end

  @tag :smart_token
  test "Account Verification - IP Not In WhiteList" do
    user_ref = {:ref, SmartTokenTest.User, 1234}
    bindings = %{recipient: user_ref}
    smart_token = SmartToken.account_verification_token(%{})
                  |> SmartToken.ip_whitelist("127.5.0.1/32")
                  |> SmartToken.bind!(bindings, @context, %{})
    encoded_link = SmartToken.encoded_key(smart_token)

    attempt = SmartToken.authorize!(encoded_link, @conn_stub, @context)
    {:error, errors} = attempt
    assert errors[:remote_ip] == {:error, {:ip_not_in_white_list, @conn_stub.remote_ip}}
  end


  @tag :smart_token
  test "Account Verification - Valid Session Secret" do
    user_ref = {:ref, SmartTokenTest.User, 1234}
    bindings = %{recipient: user_ref}
    smart_token = SmartToken.account_verification_token(%{})
                  |> SmartToken.session_value("henry", 5)
                  |> SmartToken.bind!(bindings, @context, %{})

    encoded_link = SmartToken.encoded_key(smart_token)

    {attempt, token} = SmartToken.authorize!(encoded_link, @conn_stub, @context)
    SmartToken.authorize!(encoded_link, @conn_stub, @context)
    SmartToken.authorize!(encoded_link, @conn_stub, @context)
    assert attempt == :ok
    assert smart_token.resource == user_ref
  end

  @tag :smart_token
  test "Account Verification - Invalid Session Secret" do
    user_ref = {:ref, SmartTokenTest.User, 1234}
    bindings = %{recipient: user_ref}
    smart_token = SmartToken.account_verification_token(%{})
                  |> SmartToken.session_value("henry", 6)
                  |> SmartToken.bind!(bindings, @context, %{})
    encoded_link = SmartToken.encoded_key(smart_token)

    attempt = SmartToken.authorize!(encoded_link, @conn_stub, @context)
    {:error, errors} = attempt
    assert errors[:session] == {:error, {:values, ["henry"]}}
  end


  @tag :smart_token
  test "Account Verification - Max Attempts Exceeded - Single Use" do
    user_ref = {:ref, SmartTokenTest.User, 1234}
    bindings = %{recipient: user_ref}
    smart_token = SmartToken.account_verification_token(%{})
                  |> SmartToken.bind!(bindings, @context, %{})
    encoded_link = SmartToken.encoded_key(smart_token)

    SmartToken.authorize!(encoded_link, @conn_stub, @context)
    attempt = SmartToken.authorize!(encoded_link, @conn_stub, @context)
    {:error, errors} = attempt
    assert errors[:access_count] == {:error, :single_use_exceeded}
  end


  @tag :smart_token
  test "Account Verification - Max Attempts Exceeded - Multi Use" do
    user_ref = {:ref, SmartTokenTest.User, 1234}
    bindings = %{recipient: user_ref}
    options = %{extended_info: %{multi_use: true, limit: 3}}
    smart_token = SmartToken.account_verification_token(options)
                  |> SmartToken.bind!(bindings, @context, %{})
    encoded_link = SmartToken.encoded_key(smart_token)

    {attempt, _token} = SmartToken.authorize!(encoded_link, @conn_stub, @context)
    assert attempt == :ok
    {attempt, _token} = SmartToken.authorize!(encoded_link, @conn_stub, @context)
    assert attempt == :ok
    {attempt, _token} = SmartToken.authorize!(encoded_link, @conn_stub, @context)
    assert attempt == :ok
    attempt = SmartToken.authorize!(encoded_link, @conn_stub, @context)
    {:error, errors} = attempt
    assert errors[:access_count] == {:error, :multi_use_exceeded}
  end

  @tag :smart_token
  test "Account Verification - Expired" do
    user_ref = {:ref, SmartTokenTest.User, 1234}
    bindings = %{recipient: user_ref}
    options = %{extended_info: %{multi_use: true, limit: 3}}
    smart_token = SmartToken.account_verification_token(options)
                  |> SmartToken.bind!(bindings, @context, %{})
    encoded_link = SmartToken.encoded_key(smart_token)

    {attempt, _token} = SmartToken.authorize!(encoded_link, @conn_stub, @context)
    assert attempt == :ok

    past_expiration = DateTime.utc_now() |> DateTime.shift(day: 5)
    options = %{current_time: past_expiration}
    attempt = SmartToken.authorize!(encoded_link, @conn_stub, @context, options)
    {:error, errors} = attempt
    assert errors[:period] == {:error, :gt_range}
  end


end
