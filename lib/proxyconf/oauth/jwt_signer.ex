defmodule ProxyConf.OAuth.JwtSigner do
  @moduledoc """
    A minimal JWT provider just good enough to issue JWT tokens that can be used for testing
    Never should a Production system rely on this implementation.
  """

  use Agent

  defmodule JWT do
    @moduledoc false
    use Joken.Config
  end

  @kid "proxyconf"
  @issuer "proxyconf"
  def start_link(_args) do
    pem = Application.fetch_env!(:proxyconf, :control_plane_private_key) |> File.read!()

    alg =
      case X509.PrivateKey.from_pem!(pem) |> elem(0) do
        :ECPrivateKey -> "ES256"
        :RSAPrivateKey -> "RS256"
      end

    signer = Joken.Signer.create(alg, %{"pem" => pem}, %{"kid" => @kid})
    {_, jwk} = JOSE.JWK.to_map(signer.jwk)

    jwks = %{
      "keys" => [
        %{"alg" => alg, "kid" => @kid, "use" => "sig"} |> Map.merge(jwk) |> Map.drop(["crv"])
      ]
    }

    Agent.start_link(
      fn ->
        %{signer: signer, jwks: jwks}
      end,
      name: __MODULE__
    )
  end

  def jwks do
    value = Agent.get(__MODULE__, & &1)
    value.jwks
  end

  def to_jwt(claims \\ %{}) do
    value = Agent.get(__MODULE__, & &1)

    {:ok, jwt, _} =
      JWT.generate_and_sign(
        Map.put_new(claims, "iss", @issuer),
        value.signer
      )

    jwt
  end
end
