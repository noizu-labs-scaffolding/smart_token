defmodule SmartToken.MixProject do
  use Mix.Project

  def project do
    [
      app: :smart_token,
      version: "0.1.0",
      elixir: "~> 1.15",
      package: package(),
      deps: deps(),
      description: "Smart Token - A simple token generator for authentication and authorization.",
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env),
    ]
  end

  defp package do
    [
      maintainers: ["noizu"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/noizu-labs-scaffolding/SmartToken"}
    ]
  end # end package


  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_uuid, "~> 1.2"},
      {:shortuuid, "~> 3.0"},
      {:noizu_labs_core, "~> 0.1.3"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp docs do
    [
      source_url_pattern: "https://github.com/noizu-labs-scaffolding/SmartToken/blob/master/%{path}#L%{line}",
      extras: ["README.md"]
    ]
  end # end docs


  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

end
