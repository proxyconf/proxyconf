defmodule ProxyConf.OAuth.Application do
  use Ecto.Schema
  use ExOauth2Provider.Applications.Application, otp_app: :proxyconf

  schema "oauth_applications" do
    application_fields()

    timestamps()
  end
end
