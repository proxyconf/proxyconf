defmodule ApiFence.MixProject do
  use Mix.Project

  def project do
    [
      app: :api_fence,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ApiFence.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:envoy_xds, git: "https://github.com/apifence/envoy_xds_ex.git"},
      {:json_xema, "~> 0.6.2"},
      {:jsonpatch, "~> 2.2"},
      {:elixir_map_to_xml, "~> 0.1.0"},
      {:plug, "~> 1.16"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.9"},
      {:deep_merge, "~> 1.0"},
      {:file_system, "~> 1.0"},
      {:api_fence_validator, path: "../api_fence_validator"},
      {:x509, "~> 0.8.9"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
