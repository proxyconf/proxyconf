defmodule ProxyConf.ConfigGenerator.VHost do
  use ProxyConf.MapTemplate

  deftemplate(%{
    "name" => :name,
    "domains" => :domains,
    "routes" => :routes
  })

  def from_spec_gen(spec) do
    host = spec.api_url.host

    fn routes ->
      %{
        name: host,
        domains: [host],
        routes: routes
      }
      |> eval()
    end
  end
end
