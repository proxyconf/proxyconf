defmodule ProxyConf.RoutingTest do
  use ExUnit.Case, async: false
  use ProxyConf.TestSupport.Oas3Case

  oas3spec("test/oas3/basic-routing-with-auth.yaml", ctx)
  @tag :wip
  oas3spec("test/oas3/basic-routing-with-basic-auth.yaml", ctx)
  oas3spec("test/oas3/basic-routing-with-query-auth.yaml", ctx)

  oas3spec("test/oas3/basic-routing-no-auth.yaml", ctx)
  oas3spec("test/oas3/basic-routing-multiple-servers.yaml", ctx)
  oas3spec("test/oas3/basic-routing-request-body.yaml", ctx)

  oas3spec(
    "test/oas3/error-missing-downstream-config.yaml",
    ctx
  ) do
    fn
      %Finch.Response{status: 404}, prop ->
        assert prop.status in ["404", "500"]

      %Mint.TransportError{} = _resp, prop ->
        assert prop.status == "500"
    end
  end
end
