import Config


config :smart_token,
       hooks: [
         save_token: &SmartTokenTest.Hooks.save_token/3,
         get_token: &SmartTokenTest.Hooks.get_token/1,
         get_by_token: &SmartTokenTest.Hooks.get_by_token/2,
       ]
