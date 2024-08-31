defmodule ProxyConf.JwtTest do
  defmodule ValidToken do
    use ExUnit.Case, async: false
    use ProxyConf.TestSupport.Oas3Case, jwt_claims: %{"aud" => "exunit"}

    oas3spec("test/oas3/jwt-auth.yaml", ctx)
  end

  defmodule InvalidAudienceClaim do
    use ExUnit.Case, async: false
    use ProxyConf.TestSupport.Oas3Case, jwt_claims: %{"aud" => "exunit-wrong"}

    oas3spec("test/oas3/jwt-auth.yaml", ctx) do
      fn %Finch.Response{status: 403}, _ ->
        assert true
      end
    end
  end

  defmodule InvalidIssuerClaim do
    use ExUnit.Case, async: false

    use ProxyConf.TestSupport.Oas3Case,
      jwt_claims: %{"iss" => "proxyconf-exunit-wrong", "aud" => "exunit"}

    oas3spec("test/oas3/jwt-auth.yaml", ctx) do
      fn %Finch.Response{status: 401}, _ ->
        assert true
      end
    end
  end

  defmodule MissingToken do
    use ExUnit.Case, async: false
    use ProxyConf.TestSupport.Oas3Case

    oas3spec("test/oas3/jwt-auth.yaml", ctx) do
      fn %Finch.Response{status: 403}, _ ->
        assert true
      end
    end
  end
end
