defmodule ProxyConf.TestSupport.Oas3Case do
  @moduledoc """

    A macro to generate test cases from OpenAPI spec
    that run agains ProxyConf


    The macro parts are inspired by  the StreamData 
    property based testing library 

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

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      setup_all do
        ctx =
          TestSupport.Envoy.start_envoy(%{
            cluster_id: "proxyconf-exunit",
            admin_port: Enum.random(30000..40000),
            listener_port: Enum.random(40001..50000),
            log_level: :error,
            log_path: "/tmp/envoy-test-proxyconf-exunit.log"
          })

        on_exit(fn ->
          try do
            Port.close(ctx.port)
          rescue
            _ -> :ok
          end
        end)

        {:ok, ctx}
      end

      setup do
        # Application.ensure_all_started(:finch)

        on_exit(fn ->
          # for unknown reason having an IO.inspect here helps to prevent the race condition
          IO.inspect("on exit")
          # Application.stop(:mint)
          # Application.stop(:finch)
        end)

        {:ok, []}
      end
    end
  end

  defp listener_name_from_spec(spec) do
    listener = Map.get(spec, "x-proxyconf-listener", %{})
    address = Map.get(listener, "address", "127.0.0.1")
    port = Map.get(listener, "port", 8080)
    "#{address}:#{port}"
  end

  defp wait_until_listener_setup(ctx, spec, retries \\ 10)

  defp wait_until_listener_setup(_ctx, spec, 0) do
    listener = listener_name_from_spec(spec)
    Logger.warning("Listener #{listener} not ready, giving up")
  end

  defp wait_until_listener_setup(ctx, spec, n) do
    name = listener_name_from_spec(spec)

    %Finch.Response{status: 200, body: body} =
      http_req(:get, "http://localhost:#{ctx.admin_port}/listeners?format=json")

    with %{"listener_statuses" => listeners} <- Jason.decode!(body),
         listeners <- Enum.map(listeners, fn %{"name" => name} -> name end),
         true <- name in listeners do
      :ok
    else
      _ ->
        Process.sleep(1000)
        wait_until_listener_setup(ctx, spec, n - 1)
    end
  rescue
    Mint.TransportError ->
      Process.sleep(1000)
      wait_until_listener_setup(ctx, spec, n - 1)
  end

  def test_property_stream(ctx, spec_file, n, assert_fn) do
    {:ok, %ProxyConf.Types.Spec{spec: %{"servers" => servers} = spec}} =
      ProxyConf.ConfigCache.parse_spec_file(spec_file)

    finch_name = String.to_atom("ProxyConfFinch#{:erlang.phash2(spec_file)}")
    {:ok, _pid} = Finch.start_link(name: finch_name, protocol: :http1, size: 1, count: 1)

    bypasses =
      Enum.map(servers, fn %{"url" => url} ->
        %URI{port: port} = URI.parse(url)
        Bypass.open(port: port)
      end)

    ctx =
      case TestSupport.Oidc.maybe_setup_jwt_auth(spec) do
        {:ok, jwt, _} ->
          Map.put(ctx, :jwt_auth, jwt)

        {:error, :no_jwt_auth_defined} ->
          ctx
      end

    ctx = Map.put(ctx, :finch, finch_name) |> Map.put(:bypasses, bypasses)
    ProxyConf.ConfigCache.load_external_spec(spec_file, spec)
    wait_until_listener_setup(ctx, spec)

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
            {header,
             List.flatten(Map.get(value, "examples", []) ++ [Map.get(value, "example", [])])}
          end)

        response_body_samples_for_media_type =
          List.flatten(
            Map.get(media_type_object, "examples", []) ++
              [Map.get(media_type_object, "example", [])]
          )

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
          response_headers: response_headers |> shuffler()
        }
        |> shuffle()
      end)
    end)
  end

  defp property_stream(
         %{
           "paths" => paths,
           "x-proxyconf-api-url" => api_url
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
        "?" <> (Enum.map(prop.query_parameters, fn {k, v} -> k <> "=" <> v end) |> Enum.join("&"))
      else
        ""
      end

    prop = %{prop | path: path}
    uri = URI.new!(prop.api_url <> path <> querystring)

    Enum.each(bypasses, fn bypass ->
      Bypass.stub(bypass, "#{prop.method}" |> String.upcase(), path, fn conn ->
        response_headers = prop.response_headers || []

        Enum.reduce(response_headers, conn, fn {k, v}, acc ->
          Plug.Conn.put_resp_header(acc, k, v)
        end)
        |> Plug.Conn.put_resp_header("Content-Type", prop.response_media_type)
        |> Plug.Conn.resp(status, prop.response_body)
      end)
    end)

    request_headers =
      case Map.get(ctx, :jwt_auth) do
        nil -> prop.request_headers
        jwt -> Map.put(prop.request_headers, "Authorization", "Bearer " <> jwt)
      end

    resp = http_req(prop.method, uri, prop.request_body, request_headers |> Enum.into([]), finch)

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
        {k, v} when is_function(v) ->
          {k, v.()}

        {k, v} ->
          {k, v}
      end)
      |> Map.new()
    end
  end
end
