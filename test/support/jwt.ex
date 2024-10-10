defmodule ProxyConf.TestSupport.Jwt do
  @moduledoc false
  defmodule JWT do
    @moduledoc false
    use Joken.Config
  end

  @pem """
  -----BEGIN RSA PRIVATE KEY-----
  MIICWwIBAAKBgQDdlatRjRjogo3WojgGHFHYLugdUWAY9iR3fy4arWNA1KoS8kVw33cJibXr8bvwUAUparCwlvdbH6dvEOfou0/gCFQsHUfQrSDv+MuSUMAe8jzKE4qW+jK+xQU9a03GUnKHkkle+Q0pX/g6jXZ7r1/xAK5Do2kQ+X5xK9cipRgEKwIDAQABAoGAD+onAtVye4ic7VR7V50DF9bOnwRwNXrARcDhq9LWNRrRGElESYYTQ6EbatXS3MCyjjX2eMhu/aF5YhXBwkppwxg+EOmXeh+MzL7Zh284OuPbkglAaGhV9bb6/5CpuGb1esyPbYW+Ty2PC0GSZfIXkXs76jXAu9TOBvD0ybc2YlkCQQDywg2R/7t3Q2OE2+yo382CLJdrlSLVROWKwb4tb2PjhY4XAwV8d1vy0RenxTB+K5Mu57uVSTHtrMK0GAtFr833AkEA6avx20OHo61Yela/4k5kQDtjEf1N0LfI+BcWZtxsS3jDM3i1Hp0KSu5rsCPb8acJo5RO26gGVrfAsDcIXKC+bQJAZZ2XIpsitLyPpuiMOvBbzPavd4gY6Z8KWrfYzJoI/Q9FuBo6rKwl4BFoToD7WIUS+hpkagwWiz+6zLoX1dbOZwJACmH5fSSjAkLRi54PKJ8TFUeOP15h9sQzydI8zJU+upvDEKZsZc/UhT/SySDOxQ4G/523Y0sz/OZtSWcol/UMgQJALesy++GdvoIDLfJX5GBQpuFgFenRiRDabxrE9MNUZ2aPFaFp+DyAe+b4nDwuJaW2LURbr8AEZga7oQj0uYxcYw==
  -----END RSA PRIVATE KEY-----
  """

  @issuer "proxyconf-exunit"
  def maybe_setup_jwt_auth(%{
        "x-proxyconf" => %{
          "security" => %{
            "auth" => %{
              "downstream" => %{
                "type" => "jwt",
                "provider-config" => %{
                  # issuer is ignored, this allows to check wrong issuer validation failure
                  "issuer" => _issuer,
                  "remote_jwks" => %{"http_uri" => %{"uri" => jwks_uri}}
                }
              }
            }
          }
        }
      }) do
    alg = "RS256"
    kid = "mykid"
    signer = Joken.Signer.create(alg, %{"pem" => @pem}, %{"kid" => kid})
    {_, %{"kty" => kty, "n" => n, "e" => e}} = signer.jwk |> JOSE.JWK.to_map()

    jwks = %{
      "keys" => [
        %{"alg" => alg, "kid" => kid, "use" => "sig", "kty" => kty, "e" => e, "n" => n}
      ]
    }

    %URI{port: port, path: path} = URI.parse(jwks_uri)
    bypass = Bypass.open(port: port)

    Bypass.stub(bypass, "GET", path, fn conn ->
      Plug.Conn.put_resp_header(conn, "Content-Type", "application/json")
      |> Plug.Conn.resp(200, Jason.encode!(jwks))
    end)

    {:ok, signer}
  end

  def maybe_setup_jwt_auth(_spec), do: {:error, :no_jwt_auth_defined}

  def gen_jwt(claims, signer) do
    {:ok, jwt, _} =
      JWT.generate_and_sign(
        Map.put_new(claims, "iss", @issuer),
        signer
      )

    jwt
  end
end
