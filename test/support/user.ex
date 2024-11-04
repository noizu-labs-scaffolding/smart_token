defmodule SmartTokenTest.User do
  require Noizu.EntityReference.Records
  alias Noizu.EntityReference.Records, as: R
  defstruct [
    id: nil
  ]

  def ref(r = R.ref(module: __MODULE__)) do
    {:ok, r}
  end

end
