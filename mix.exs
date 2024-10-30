defmodule ProxyConf.MixProject do
  use Mix.Project

  def project do
    [
      app: :proxyconf,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [
        ignore_modules: [
          Jason.Encoder.URI,
          Mix.Tasks.GenMarkdown,
          Inspect.ProxyConf.MapTemplate
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ProxyConf.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:envoy_xds, git: "https://github.com/proxyconf/envoy_xds_ex.git"},
      {:json_xema, "~> 0.6.2"},
      {:plug, "~> 1.16"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.9"},
      {:quantum, "~> 3.0"},
      {:deep_merge, "~> 1.0"},
      {:file_system, "~> 1.0"},
      {:joken, "~> 2.6"},
      #      {:proxyconf_validator, path: "../proxyconf_validator", optional: true},
      {:x509, "~> 0.8.9"},
      {:ymlr, "~> 5.1", only: [:test, :dev]},
      {:gen_json_schema, git: "https://github.com/dergraf/gen_json_schema.git"},
      {:credo, "~> 1.7", only: [:test, :dev]}
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end
end
