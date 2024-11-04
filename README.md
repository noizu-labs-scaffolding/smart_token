# SmartToken
Smart Tokens provide a mechanism to associate a query token with a given set of permissions and access attempts.
It may be used, for example, for a single login link, or to allow 5 downloads of a specific file.

- Time Limited Tokens
- Use Limited Tokens
- Permission Grant
- Context (limit permission grant to specific entities)
- Tamper Protection

## Installation
```elixir
def deps do
  [
    {:smart_token, "~> 0.1.0"}
  ]
end
```
