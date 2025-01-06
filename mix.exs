defmodule ProxyConfUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    []
  end
end
