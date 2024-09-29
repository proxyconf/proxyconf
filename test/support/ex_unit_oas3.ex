defmodule ProxyConf.TestSupport.Oas3Case do
  @moduledoc """

    A macro to generate test cases from OpenAPI spec
    that run agains ProxyConf


    The macro parts are inspired by  the StreamData 
    property based testing library 

    If no port is provided as part of the upstream server
    URL, a random port is used for the testing. If one want's
    to test a scenario where multiple specs use the same upstream
    server one would need to specify the port explicitely.

    The port specified in `x-proxyconf/listener` is ignored and
    random value is assigned. One can override this behaviour by
    explicitely providing the `listener_port` macro option.

  """
  import ProxyConf.TestSupport.Common
  alias ProxyConf.TestSupport
  require Logger
  use ExUnit.Case

  defmodule Error do
    @moduledoc false
    defexception [:message]
  end

  defimpl Jason.Encoder, for: URI do
    def encode(value, opts) do
      Jason.Encode.string(URI.to_string(value), opts)
    end
  end

  defmacro oas3spec(spec_file, context, contents \\ nil) do
    ExUnit.plural_rule("oas3spec", "oas3specs")

    contents =
      case contents do
        [do: block] ->
          quote do
            test_property_stream(
              unquote(context),
              unquote(spec_file),
              Map.get(unquote(context), :iterations, 100),
              unquote(block)
            )

            :ok
          end

        _ ->
          quote do
            test_property_stream(
              unquote(context),
              unquote(spec_file),
              Map.get(unquote(context), :iterations, 100),
              &prop_assert/2
            )

            :ok
          end
      end

    context = Macro.escape(context)
    contents = Macro.escape(contents, unquote: true)

    quote bind_quoted: [context: context, contents: contents, spec_file: spec_file] do
      %{module: mod, file: file, line: line} = __ENV__

      name = ExUnit.Case.register_test(mod, file, line, :oas3spec, spec_file, [:oas3spec])
      def unquote(name)(unquote(context)), do: unquote(contents)
    end
  end

  def next_port do
    Enum.random(40_000..50_000)
  end

  defmacro __using__(opts) do
    quote do
      import unquote(__MODULE__)

      setup_all do
        listener_port = next_port()
        cluster_id = "proxyconf-exunit-#{__MODULE__}"

        ctx =
          TestSupport.Envoy.start_envoy(%{
            cluster_id: cluster_id,
            admin_port: next_port(),
            listener_port: listener_port,
            log_level: :info,
            log_path: "/tmp/envoy-#{cluster_id}.log"
          })

        on_exit(fn ->
          try do
            Port.close(ctx.port)
          rescue
            _ -> :ok
          end
        end)

        opts = Enum.into(unquote(opts), %{})

        {:ok,
         ctx
         |> Map.merge(%{
           http_schema: "http",
           listener_port: listener_port,
           cluster_id: cluster_id
         })
         |> Map.merge(opts)}
      end
    end
  end

  defp wait_until_listener_setup(ctx, listner, retries \\ 10)

  defp wait_until_listener_setup(_ctx, listener, 0) do
    Logger.warning("Listener #{listener} not ready, giving up")
  end

  defp wait_until_listener_setup(ctx, listener, n) do
    %Finch.Response{status: 200, body: body} =
      http_req(:get, "http://localhost:#{ctx.admin_port}/listeners?format=json")

    with %{"listener_statuses" => listeners} <- Jason.decode!(body),
         listeners <- Enum.map(listeners, fn %{"name" => name} -> name end),
         true <- listener in listeners do
      :ok
    else
      _ ->
        Process.sleep(1000)
        wait_until_listener_setup(ctx, listener, n - 1)
    end
  rescue
    Mint.TransportError ->
      Process.sleep(1000)
      wait_until_listener_setup(ctx, listener, n - 1)
  end

  def test_property_stream(ctx, spec_file, n, assert_fn) do
    api_id = "api-#{:erlang.phash2(spec_file)}"

    overrides = %{
      "x-proxyconf" => %{
        "url" => "#{ctx.http_schema}://localhost:#{ctx.listener_port}/#{api_id}",
        "api_id" => api_id,
        "cluster" => ctx.cluster_id,
        "listener" => %{
          "address" => "127.0.0.1",
          "port" => ctx.listener_port
        }
      }
    }

    {:ok,
     %ProxyConf.Spec{
       spec: %{"servers" => servers} = spec,
       listener_port: listener_port,
       listener_address: listener_address
     }} =
      ProxyConf.ConfigCache.parse_spec_file(spec_file, overrides)

    servers =
      Enum.map(servers, fn %{"url" => url} = server ->
        if String.match?(url, ~r/^[a-z,0-9\.]+:\d+$/) do
          # port is provided, keep as is
          server
        else
          Map.put(server, "url", "#{url}:#{next_port()}")
        end
      end)

    spec = Map.put(spec, "servers", servers)

    finch_name = String.to_atom("ProxyConfFinch#{:erlang.phash2({ctx.cluster_id, spec_file})}")

    {:ok, _pid} =
      Finch.start_link(
        name: finch_name,
        protocol: :http1,
        size: 1,
        pools: %{
          default: [
            conn_opts: [
              transport_opts: [
                {:cacertfile, Application.fetch_env!(:proxyconf, :ca_certificate)}
                | case Map.get(ctx, :client_certificate) do
                    nil ->
                      []

                    wrapper_fn ->
                      {cert, private_key} = wrapper_fn.()
                      cert = X509.Certificate.from_pem!(cert) |> X509.Certificate.to_der()

                      private_key =
                        X509.PrivateKey.from_pem!(private_key) |> X509.PrivateKey.to_der()

                      [certs_keys: [%{cert: cert, key: {:ECPrivateKey, private_key}}]]
                  end
              ]
            ]
          ]
        }
      )

    ProxyConf.ConfigCache.load_external_spec(spec_file, spec)

    bypasses =
      Enum.flat_map(servers, fn %{"url" => url} ->
        case URI.parse(url) do
          %URI{port: nil} ->
            # in some test cases we want to provide invalid urls
            []

          %URI{port: port} ->
            [Bypass.open(port: port)]
        end
      end)

    ctx =
      case TestSupport.Jwt.maybe_setup_jwt_auth(spec) do
        {:ok, signer} ->
          Map.put(ctx, :jwt_signer, signer)

        {:error, :no_jwt_auth_defined} ->
          ctx
      end

    ctx = Map.put(ctx, :finch, finch_name) |> Map.put(:bypasses, bypasses)
    wait_until_listener_setup(ctx, "#{listener_address}:#{listener_port}")

    property_stream(spec)
    |> Enum.reduce_while(0, fn prop, acc ->
      if acc < n do
        {:cont, test_property(prop, ctx, acc, assert_fn)}
      else
        {:halt, :ok}
      end
    end)
  end

  defp to_prop(api_url, path, method, path_op, spec) do
    parameters =
      Map.get(path_op, "parameters", [])
      |> Enum.map(fn p ->
        case Map.get(p, "$ref") do
          nil ->
            p

          ref ->
            ["#" | ref_path] = String.split(ref, "/")
            get_in(spec, ref_path)
        end
      end)
      |> Enum.group_by(fn p -> Map.get(p, "in") end, fn p ->
        {Map.fetch!(p, "name"),
         List.flatten(Map.get(p, "examples", []) ++ [Map.get(p, "example", [])])}
      end)
      |> Enum.map(fn {loc, params_for_loc} ->
        {loc, Map.new(params_for_loc)}
      end)
      |> Map.new()

    Map.get(path_op, "requestBody", %{"content" => %{no_payload: %{}}})
    |> Map.fetch!("content")
    |> Enum.map(fn {media_type, media_type_object} ->
      request_body_samples_for_media_type =
        List.flatten(
          Map.get(media_type_object, "examples", []) ++
            [Map.get(media_type_object, "example", [])]
        )

      Map.get(path_op, "responses", %{})
      |> Enum.filter(fn {_status_code, response_object} ->
        response_body = Map.get(response_object, "content", %{})
        Map.has_key?(response_body, media_type) or media_type == :no_payload
      end)
      |> Enum.map(fn {status_code, response_object} ->
        {response_media_type, media_type_object} =
          if media_type == :no_payload do
            Enum.at(Map.get(response_object, "content", []), 0, {:no_payload, %{}})
          else
            {media_type, get_in(response_object, ["content", media_type])}
          end

        response_headers =
          Map.get(response_object, "headers", %{})
          |> Enum.map(fn {header, value} ->
            {header, List.flatten([Map.get(value, "example", [])])}
          end)

        response_body_samples_for_media_type =
          List.flatten([Map.get(media_type_object, "example", [])])

        %{
          api_url: api_url,
          method: String.to_existing_atom(method),
          path: path,
          request_media_type: media_type,
          response_media_type: response_media_type,
          path_parameters: Map.get(parameters, "path", %{}) |> shuffler(),
          query_parameters: Map.get(parameters, "query", %{}) |> shuffler(),
          request_headers: Map.get(parameters, "header", %{}) |> shuffler(),
          request_body: request_body_samples_for_media_type |> shuffler(),
          status: status_code,
          response_body: response_body_samples_for_media_type |> shuffler(),
          response_headers: response_headers |> shuffler(),
          upstream_auth: upstream_auth_to_property(spec)
        }
        |> shuffle()
      end)
    end)
  end

  defp upstream_auth_to_property(%{
         "x-proxyconf" => %{
           "security" => %{"auth" => %{"upstream" => %{"type" => "header"} = upstream_auth}}
         }
       }) do
    fn %Plug.Conn{} = conn ->
      assert List.keyfind!(conn.req_headers, upstream_auth["name"], 0) |> elem(1) ==
               upstream_auth["value"]
    end
  end

  defp upstream_auth_to_property(_), do: fn _conn -> true end

  defp property_stream(
         %{
           "paths" => paths,
           "x-proxyconf" => %{"url" => api_url}
         } = spec
       ) do
    props =
      Enum.map(paths, fn {path, path_ops} ->
        Enum.map(path_ops, fn
          {"$ref", referenced_path_item} ->
            ["#" | ref_path] = Path.split(referenced_path_item)

            get_in(spec, ref_path)
            |> Enum.map(fn {method, path_op} ->
              to_prop(api_url, path, method, path_op, spec)
            end)

          {method, path_op} ->
            to_prop(api_url, path, method, path_op, spec)
        end)
      end)
      |> List.flatten()

    Stream.repeatedly(fn ->
      prop = Enum.random(props)
      prop.()
    end)
  end

  defp test_property(prop, ctx, n, assert_fn) do
    bypasses = ctx.bypasses
    finch = ctx.finch
    status = String.to_integer(prop.status)

    path =
      Enum.reduce(prop.path_parameters, prop.path, fn {path_parameter, path_parameter_value},
                                                      acc ->
        String.replace(acc, "{#{path_parameter}}", "#{path_parameter_value}")
      end)

    querystring =
      if map_size(prop.query_parameters) > 0 do
        "?" <> Enum.map_join(prop.query_parameters, "&", fn {k, v} -> k <> "=" <> v end)
      else
        ""
      end

    prop = %{prop | path: path}
    uri = URI.new!(prop.api_url <> path <> querystring)

    Enum.each(bypasses, fn bypass ->
      Bypass.stub(bypass, "#{prop.method}" |> String.upcase(), path, fn conn ->
        assert prop.upstream_auth.(conn)

        response_headers = prop.response_headers || []

        Enum.reduce(response_headers, conn, fn {k, v}, acc ->
          Plug.Conn.put_resp_header(acc, k, v)
        end)
        |> Plug.Conn.put_resp_header("Content-Type", prop.response_media_type)
        |> Plug.Conn.resp(status, prop.response_body)
      end)
    end)

    request_headers =
      case Map.get(ctx, :jwt_signer) do
        nil ->
          prop.request_headers

        signer ->
          jwt = TestSupport.Jwt.gen_jwt(Map.get(ctx, :jwt_claims, %{}), signer)
          Map.put(prop.request_headers, "Authorization", "Bearer " <> jwt)
      end

    resp =
      http_req(
        prop.method,
        uri,
        prop.request_body,
        request_headers |> Enum.into([]),
        finch
      )

    assert(assert_fn.(resp, prop))
    IO.write(".")
    n + 1
  rescue
    e in Mint.TransportError ->
      assert(assert_fn.(e, prop))

    e ->
      result = %{
        exception: e,
        stacktrace: __STACKTRACE__,
        generated_req_resp: prop,
        successful_runs: n
      }

      unquote(__MODULE__).__raise__(result)
  end

  def prop_assert(
        %Finch.Response{status: resp_status, body: response_body, headers: response_headers},
        prop
      ) do
    # Generating a good looking AssertionError
    assert(
      %{response: response_body, status: "#{resp_status}"} == %{
        response: prop.response_body,
        status: prop.status
      }
    )

    assert(
      Enum.find_value(response_headers, fn {h, v} -> if h == "content-type", do: v end) ==
        prop.response_media_type
    )

    true
  end

  def __raise__(%{
        exception: exception,
        stacktrace: stacktrace,
        successful_runs: successful_runs,
        generated_req_resp: prop
      }) do
    {exception, stacktrace} = Exception.blame(:error, exception, stacktrace)
    formatted_exception = Exception.format_banner(:error, exception, stacktrace)

    message =
      "failed with generated values (after #{successful_runs(successful_runs)}):\n\n" <>
        Jason.encode!(prop, pretty: true) <>
        "\n\ngot exception:\n\n" <> formatted_exception

    reraise Error, [message: message], stacktrace
  end

  defp successful_runs(1), do: "1 successful run"
  defp successful_runs(n), do: "#{n} successful runs"

  defp shuffler(list) when is_list(list) do
    fn ->
      if list == [] do
        []
      else
        Enum.random(list)
      end
    end
  end

  defp shuffler(enum) when is_map(enum) do
    fn ->
      Enum.map(enum, fn
        {k, values} when is_list(values) ->
          {k, Enum.random(values)}
      end)
      |> Map.new()
    end
  end

  defp shuffle(map) when is_map(map) do
    fn ->
      Enum.map(map, fn
        {:upstream_auth, ua} ->
          {:upstream_auth, ua}

        {k, v} when is_function(v) ->
          {k, v.()}

        {k, v} ->
          {k, v}
      end)
      |> Map.new()
    end
  end
end
