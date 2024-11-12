defmodule SmartToken.Repo.Migrations.Setup do
  use Ecto.Migration

  def up do
    SmartToken.Migration.up(1)
  end

  def up do
    SmartToken.Migration.down(1)
  end
end
