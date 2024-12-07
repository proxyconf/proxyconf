defmodule ProxyConf.OAuth.AccessToken do
  use Ecto.Schema
  use ExOauth2Provider.AccessTokens.AccessToken, otp_app: :proxyconf

  schema "oauth_access_tokens" do
    access_token_fields()

    timestamps()
  end

  # custom generator
  def generate(access_token) do
    created_at = DateTime.from_naive!(access_token[:created_at], "Etc/UTC")

    ProxyConf.OAuth.JwtSigner.to_jwt(%{
      "scopes" => access_token[:scopes],
      "exp" =>
        created_at
        |> DateTime.add(access_token[:expires_in], :second)
        |> DateTime.to_unix(),
      "nbf" => created_at |> DateTime.to_unix(),
      "iat" => created_at |> DateTime.to_unix(),
      "aud" => access_token[:application].name
    })
  end
end
