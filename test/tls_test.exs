defmodule ProxyConf.TlsTest do
  use ExUnit.Case, async: true
  use ProxyConf.TestSupport.Oas3Case, http_schema: "https"

  oas3spec("test/oas3/tls.yaml", ctx)
end
