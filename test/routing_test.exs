defmodule ProxyConf.RoutingTest do
  use ExUnit.Case, async: true
  use ProxyConf.TestSupport.Oas3Case

  oas3spec("test/oas3/basic-routing-with-auth.yaml", ctx)
  oas3spec("test/oas3/basic-routing-with-basic-auth.yaml", ctx)
  oas3spec("test/oas3/basic-routing-with-query-auth.yaml", ctx)

  oas3spec("test/oas3/basic-routing-no-auth.yaml", ctx)
  oas3spec("test/oas3/basic-routing-multiple-servers.yaml", ctx)
  oas3spec("test/oas3/basic-routing-request-body.yaml", ctx)

  oas3spec("test/oas3/error-invalid-upstream.yaml", ctx) do
    fn
      %Mint.TransportError{reason: :econnrefused}, _ ->
        # can happen if it is the first test
        assert true

      %Finch.Response{status: 403}, prop ->
        assert prop.status in ["403"]
    end
  end

  oas3spec(
    "test/oas3/error-missing-downstream-config.yaml",
    ctx
  ) do
    fn
      %Mint.TransportError{reason: :econnrefused}, _ ->
        # can happen if it is the first test
        assert true

      %Finch.Response{status: 403}, prop ->
        assert prop.status in ["403"]
    end
  end
end
