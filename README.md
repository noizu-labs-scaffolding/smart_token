# SmartToken
Smart Tokens provide a mechanism to associate a query token with a given set of permissions and access attempts.
It may be used, for example, for a single login link, or to allow 5 downloads of a specific file.

- Time Limited Tokens
- Use Limited Tokens
- Permission Grant
- Context (limit permission grant to specific entities)
- Tamper Protection

# Setup

## 1. Add SmartToken to your mix.exs file.
```elixir
def deps do
  [
    {:smart_token, "~> 0.1.1"}
  ]
end
```
## 2. Set config.exs repo or schema for smart token.

#### Repo - you ecto repo where the SmartToken table will be stored
```elixir
config :smart_token, repo: MyApp.Repo
```
#### Schema - you ecto schema where the SmartToken table will be stored
Schema module must implement the SmartToken.Schema behaviour. Note get_token, lookup_token should insure the nested smart_token element's identifier field is set to the id of the record if
not set on create.

See `SSmartToken.Schema.SmartToken` for an example implementation.

```elixir
config :smart_token, schema: MyApp.Schema.SmartToken
```


## 3. Setup migration 

### Run
``` 
mix ecto.gen.migration setup_smart_tokens 
```
    
### Edit migration file:
```
defmodule MyApp.Repo.Migrations.SetupSmartTokens do
  use Ecto.Migration

  def up() do 
    SmartTokens.Migration.up(1)
  end

  def down() do 
    SmartTokens.Migration.down(1)
  end
end
```
