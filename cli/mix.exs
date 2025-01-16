defmodule ProxyConf.CLI.MixProject do
  use Mix.Project

  def project do
    [
      app: :proxyconf_cli,
      version: "0.1.0",
      build_path: "../_build",
      config_path: "config/config.exs",
      deps_path: "../deps",
      lockfile: "mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ProxyConf.CLI, []},
      extra_applications: [:logger]
    ]
  end

  def releases do
    [
      proxyconf_cli: [
        applications: [proxyconf_cli: :permanent],
        steps: [:assemble, &Burrito.wrap/1],
        burrito: [
          targets: [
            linux: [
              os: :linux,
              cpu: :x86_64,
              custom_erts: "#{:code.root_dir()}"
            ]
          ]
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:burrito, "~> 1.0"},
      {:optimus, "~> 0.5.0"},
      {:proxyconf_commons, path: "../commons"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true}
    ]
  end

  defp aliases do
    [
      test: ["test --no-start"]
    ]
  end
end
