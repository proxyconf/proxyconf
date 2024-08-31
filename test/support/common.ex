defmodule ProxyConf.TestSupport.Common do
  @moduledoc false
  require Logger

  def http_req(method, url, body \\ nil, headers \\ [], finch \\ ProxyConfFinch) do
    request = Finch.build(method, url, [{"Host", "localhost"} | headers], body)
    Finch.request!(request, finch)
  end

  def parse_oas3(file) do
    {:ok, spec} = ProxyConf.ConfigCache.parse_spec_file(file)
    spec
  end
end
