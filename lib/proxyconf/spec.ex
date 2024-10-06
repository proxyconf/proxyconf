defmodule ProxyConf.Spec do
  @moduledoc """
    This module models the internal representation of the OpenAPI spec.
  """
  require Logger
  alias ProxyConf.Ext

  defstruct([
    :filename,
    :hash,
    :cluster_id,
    :api_url,
    :api_id,
    :listener_address,
    :listener_port,
    :allowed_source_ips,
    :downstream_auth,
    :upstream_auth,
    :routing,
    :spec,
    type: :oas3
  ])

  def from_oas3(filename, spec, data) do
    %{
      "cluster" => cluster_id,
      "url" => api_url,
      "api_id" => api_id,
      "listener" => %{"address" => address, "port" => port},
      "security" => %{
        "allowed_source_ips" => allowed_source_ips,
        "auth" => %{"downstream" => downstream_auth, "upstream" => upstream_auth}
      },
      "routing" => %{
        "fail-fast-on-missing-query-parameter" => fail_fast_on_missing_query_parameter,
        "fail-fast-on-missing-header-parameter" => fail_fast_on_missing_header_parameter,
        "fail-fast-on-wrong-request-media_type" => fail_fast_on_wrong_request_media_type
      }
    } = Ext.config_from_spec(filename, spec)

    {:ok,
     %__MODULE__{
       filename: filename,
       hash: gen_hash(data),
       cluster_id: cluster_id,
       api_url: api_url,
       api_id: api_id,
       listener_address: address,
       listener_port: port,
       allowed_source_ips: allowed_source_ips,
       downstream_auth: downstream_auth,
       upstream_auth: upstream_auth,
       routing: %{
         fail_fast_on_missing_query_parameter: fail_fast_on_missing_query_parameter,
         fail_fast_on_missing_header_parameter: fail_fast_on_missing_header_parameter,
         fail_fast_on_wrong_request_media_type: fail_fast_on_wrong_request_media_type
       },
       spec: spec
     }}
  end

  def gen_hash(data) when is_binary(data) do
    :crypto.hash(:sha256, data) |> Base.encode64()
  end
end
