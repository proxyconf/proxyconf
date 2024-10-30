Application.load(:proxyconf)
ExUnit.start()
Application.ensure_all_started(:proxyconf)
