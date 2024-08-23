defmodule ProxyConf.OidcTest do
  use ExUnit.Case, async: false
  use ProxyConf.TestSupport.Oas3Case

  oas3spec("test/oas3/basic-routing-with-jwt-auth.yaml", ctx)
  oas3spec("test/oas3/basic-routing-with-wrong-jwt-auth.yaml", ctx)
  oas3spec("test/oas3/basic-routing-with-wrong-issuer-jwt-auth.yaml", ctx)
end
