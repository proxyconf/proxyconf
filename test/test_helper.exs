Application.load(:proxyconf)
{:ok, _} = Finch.start_link(name: ProxyConfFinch)
Application.ensure_all_started(:proxyconf)
ExUnit.start()

