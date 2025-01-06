defmodule ProxyConf.Commons.MixProject do
  use Mix.Project

  def project do
    [
      app: :proxyconf_commons,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:envoy_xds, git: "https://github.com/proxyconf/envoy_xds_ex.git"},
      {:jason, "~> 1.4"},
      {:recase, "~> 0.8.1"},
      {:json_xema, "~> 0.6.2"},
      {:deep_merge, "~> 1.0"},
      {:warpath, "~> 0.6.3"},
      {:bbmustache, "~> 1.12"},
      {:yaml_elixir, "~> 2.9"},
      {:ymlr, "~> 5.1", only: [:test, :dev]},
      {:gen_json_schema,
       git: "https://github.com/dergraf/gen_json_schema.git", only: [:test, :dev], runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
    ]
  end
end
