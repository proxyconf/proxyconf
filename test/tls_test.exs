defmodule ProxyConf.TlsTest do
  defmodule MutualTlsGood do
    use ExUnit.Case, async: true

    use ProxyConf.TestSupport.Oas3Case,
      http_schema: "https",
      client_certificate: ProxyConf.LocalCA.server_cert("exunit-good")

    oas3spec("test/oas3/tls.yaml", ctx)
  end

  defmodule MutualTlsBad do
    use ExUnit.Case, async: true

    use ProxyConf.TestSupport.Oas3Case,
      http_schema: "https",
      client_certificate: ProxyConf.LocalCA.server_cert("exunit-bad")

    oas3spec("test/oas3/tls.yaml", ctx) do
      fn %Finch.Response{status: 403}, _ ->
        assert true
      end
    end
  end

  defmodule MutualTlsNoCert do
    use ExUnit.Case, async: true

    use ProxyConf.TestSupport.Oas3Case,
      http_schema: "https"

    oas3spec("test/oas3/tls.yaml", ctx) do
      fn
        %Mint.TransportError{reason: _}, _ ->
          # multiple error reasons popped up during testing
          # - closed
          # - einval
          # - tls alert, certificate_required
          assert true
      end
    end
  end
end
