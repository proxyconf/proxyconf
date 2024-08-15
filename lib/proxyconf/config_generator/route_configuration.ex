defmodule ProxyConf.ConfigGenerator.RouteConfiguration do
  use ProxyConf.MapTemplate
  alias ProxyConf.ConfigGenerator.Listener

  deftemplate(%{
    "virtual_hosts" => :virtual_hosts,
    "name" => :listener_name
  })

  def from_spec_gen(spec) do
    listener_name = Listener.name(spec)

    fn vhosts ->
      %{listener_name: listener_name, virtual_hosts: vhosts} |> eval()
    end
  end
end
