defmodule ProxyConf.ConfigGenerator.VHost do
  use ProxyConf.MapTemplate

  deftemplate(%{
    "name" => :name,
    "domains" => :domains,
    "routes" => :routes
  })

  def from_spec_gen(spec) do
    [host | _] = server_names = to_server_names(spec.api_url)

    fn routes ->
      %{
        name: host,
        domains: server_names,
        routes: routes
      }
      |> eval()
    end
  end

  def server_names(%{"domains" => domains}) do
    domains
  end

  defp to_server_names(%URI{host: host, port: port}) do
    [host, "#{host}:#{port}"]
  end
end
