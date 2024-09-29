defmodule ProxyConf.ConfigGenerator.UpstreamAuth do
  @moduledoc """
    This module implements the upstream auth backed by the Envoy credential injector
  """
  alias ProxyConf.Spec

  defstruct([
    :api_id,
    :auth_type,
    :auth_field_name,
    :auth_field_value,
    :overwrite
  ])

  def from_spec_gen(%Spec{upstream_auth: nil} = spec) do
    %__MODULE__{
      api_id: spec.api_id,
      auth_type: "disabled"
    }
    |> wrap_gen()
  end

  def from_spec_gen(
        %Spec{
          upstream_auth:
            %{
              type: "header",
              name: header_name,
              value: header_value
            } = upstream_auth
        } = spec
      ) do
    %__MODULE__{
      api_id: spec.api_id,
      auth_type: "header",
      auth_field_name: header_name,
      auth_field_value: header_value,
      overwrite: Map.get(upstream_auth, :overwrite, true)
    }
    |> wrap_gen()
  end

  def to_envoy_api_specific_http_filters(upstream_auth) do
    {upstream_auth, upstream_secrets} =
      Enum.reject(upstream_auth, fn %__MODULE__{auth_type: t} -> t == "disabled" end)
      |> Enum.map(fn %__MODULE__{
                       api_id: api_id,
                       overwrite: overwrite,
                       auth_field_name: auth_field_name,
                       auth_field_value: auth_field_value
                     } ->
        credential_name = "upstream-auth-#{api_id}"

        {{api_id,
          %{
            "name" => "credential-injector",
            "typed_config" => %{
              "@type" =>
                "type.googleapis.com/envoy.extensions.filters.http.credential_injector.v3.CredentialInjector",
              "allow_request_without_credential" => false,
              "overwrite" => overwrite,
              "credential" => %{
                "name" => "envoy.http.injected_credentials.generic",
                "typed_config" => %{
                  "@type" =>
                    "type.googleapis.com/envoy.extensions.http.injected_credentials.generic.v3.Generic",
                  "credential" => %{
                    "name" => credential_name,
                    "sds_config" => %{"ads" => %{}, "resource_api_version" => "V3"}
                  },
                  "header" => auth_field_name
                }
              }
            }
          }},
         %{
           "name" => credential_name,
           "generic_secret" => %{"secret" => %{"inline_string" => auth_field_value}}
         }}
      end)
      |> Enum.unzip()

    {Map.new(upstream_auth), upstream_secrets}
  end

  defp wrap_gen(res), do: fn -> res end
end
