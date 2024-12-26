defmodule ProxyConf.ConfigGenerator.UpstreamAuth do
  @moduledoc """
    This module implements the upstream auth backed by the Envoy credential injector
  """
  alias ProxyConf.Db
  alias ProxyConf.Spec

  defstruct([
    :api_id,
    :cluster_id,
    :auth_type,
    :auth_field_name,
    :auth_field_value,
    :overwrite
  ])

  @typedoc """
    title: Header Name
    description: The header name where the credentials are injected.
  """
  @type header_name :: String.t()

  @typedoc """
    title: Header Value
    description: The header value that is injected.
  """
  @type header_value :: String.t()

  @typedoc """
    title: Authentication Type
    description:  Constant `header` identifiying that credentials should be injected in a header for authenticating upstream HTTP requests.
  """
  @type header_type :: :header

  @typedoc """
    title: Overwrite Header
    description: If set to `true` an existing header is overwritten.
    default: true
  """
  @type header_overwrite :: boolean()

  @typedoc """
    title: Upstream Authentication
    description: Configure upstream authentication options.
    required:
      - name
      - type
      - value
  """
  @type header :: %{
          name: header_name(),
          type: header_type(),
          value: header_value(),
          overwrite: header_overwrite()
        }

  @typedoc """
      title: Upstream Authentication
      description: Configure upstream authentication options.
  """
  @type t :: header()

  def config_from_json(nil) do
    config_from_json(%{"type" => "disabled"})
  end

  def config_from_json(%{"type" => type} = json) do
    %__MODULE__{
      auth_type: type,
      auth_field_name: Map.get(json, "name"),
      auth_field_value: Map.get(json, "value"),
      overwrite: Map.get(json, "overwrite", true)
    }
  end

  def from_spec_gen(%Spec{upstream_auth: upstream_auth} = spec) do
    %__MODULE__{upstream_auth | api_id: spec.api_id, cluster_id: spec.cluster_id}
    |> wrap_gen()
  end

  def to_envoy_api_specific_http_filters(upstream_auth) do
    {upstream_auth, upstream_secrets} =
      Enum.reject(upstream_auth, fn %__MODULE__{auth_type: t} -> t == "disabled" end)
      |> Enum.map(fn %__MODULE__{
                       api_id: api_id,
                       cluster_id: cluster_id,
                       overwrite: overwrite,
                       auth_field_name: auth_field_name,
                       auth_field_value: auth_field_value
                     } ->
        credential_name = "upstream-auth-#{api_id}"

        secret = Db.maybe_get_secret(cluster_id, auth_field_value)

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
           "generic_secret" => %{"secret" => %{"inline_string" => secret}}
         }}
      end)
      |> Enum.unzip()

    {Map.new(upstream_auth), upstream_secrets}
  end

  defp wrap_gen(res), do: fn -> res end
end
