defmodule ProxyConf.OidcTest do
  use ExUnit.Case, async: false
  use ProxyConf.TestSupport.Oas3Case

  oas3spec("test/oas3/basic-routing-with-jwt-auth.yaml", ctx)
end
