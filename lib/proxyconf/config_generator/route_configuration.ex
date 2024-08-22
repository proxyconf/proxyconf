defmodule ProxyConf.ConfigGenerator.RouteConfiguration do
  use ProxyConf.MapTemplate
  alias ProxyConf.ConfigGenerator.Listener

  deftemplate(%{
    "virtual_hosts" => :virtual_hosts,
    "name" => :name
  })

  def from_spec_gen(spec) do
    listener_name = Listener.name(spec)

    fn vhost_name, listener_name, vhost ->
      %{name: name(listener_name, vhost_name), virtual_hosts: [vhost]} |> eval()
    end
  end

  def name(listener_name, vhost) do
    "#{listener_name}::#{vhost}"
  end
end
