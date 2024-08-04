defmodule ProxyConf.RoutingTest do
  use ExUnit.Case, async: false
  use ProxyConf.TestSupport.Oas3Case

  oas3spec("test/oas3/basic-routing-with-auth.yaml", ctx)
  oas3spec("test/oas3/basic-routing-with-query-auth.yaml", ctx)

  oas3spec("test/oas3/basic-routing-no-auth.yaml", ctx)

  oas3spec(
    "test/oas3/error-missing-downstream-config.yaml",
    ctx
  ) do
    fn
      %Finch.Response{status: 404, body: "no matching route found"}, prop ->
        assert prop.status in ["404", "500"]

      %Mint.TransportError{} = _resp, prop ->
        assert prop.status == "500"
    end
  end
end
