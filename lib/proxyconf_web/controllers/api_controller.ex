defmodule ProxyConfWeb.ApiController do
  use ProxyConfWeb, :controller
  alias ProxyConf.Db
  alias ProxyConf.Spec
  alias ProxyConf.OaiOverlay

  def upload_spec(conn, %{"spec_name" => spec_name} = _params) do
    with {:ok, data, conn} <- read_all_body(conn),
         [content_type | _] <- get_req_header(conn, "content-type"),
         {:ok, spec} <- decode(content_type, data),
         {:ok, %Spec{} = spec} <- Spec.from_oas3(spec_name, spec, data),
         :ok <- Db.create_or_update([spec]) do
      send_resp(conn, 200, "OK")
    else
      {:error, reason} ->
        send_resp(conn, 400, "Bad Request: #{reason}")
        |> halt
    end
  end

  def upload_bundle(conn, %{"cluster_id" => cluster_id} = _params) do
    with {:ok, data, conn} <- read_all_body(conn),
         {specs, []} <- iterate_zip_contents(data, cluster_id),
         :ok <- Db.create_or_update(specs, sync: cluster_id) do
      send_resp(conn, 200, "OK")
    else
      {:error, reason} ->
        send_resp(conn, 400, "Bad Request: #{reason}")
        |> halt

      {_specs, errors} ->
        error_summary =
          Enum.map(errors, fn {filename, reason} ->
            "- #{filename}: #{reason}"
          end)
          |> Enum.join("\n")

        send_resp(conn, 400, "Bad Request:\n#{error_summary}")
        |> halt
    end
  end

  def echo(conn, _params) do
    {:ok, data, conn} = read_all_body(conn)

    conn =
      fetch_query_params(conn)

    headers = conn.req_headers
    query_params = conn.query_params

    resp =
      %{
        headers: Map.new(headers),
        query_params: Map.new(query_params),
        body: data,
        method: conn.method
      }
      |> Jason.encode!()

    put_resp_header(conn, "Content-Type", "application/json")
    |> send_resp(200, resp)
  end

  defp read_all_body(conn, body_parts \\ []) do
    case read_body(conn) do
      {:ok, data, conn} ->
        {:ok, [data | body_parts] |> Enum.reverse() |> :erlang.iolist_to_binary(), conn}

      {:more, data, conn} ->
        read_all_body(conn, [data | body_parts])

      {:error, _reason} = e ->
        e
    end
  end

  defp iterate_zip_contents(zip_data, cluster_id) do
    result =
      :zip.foldl(
        fn filename, _fileinfo_fn, filedata_fn, {spec_acc, overlay_acc, error_acc} ->
          ext = Path.extname(filename)

          with true <- ext in [".json", ".yaml"],
               data_raw <- filedata_fn.(),
               {:ok, data} <- decode(ext, data_raw) do
            cond do
              Map.has_key?(data, "openapi") ->
                {[{"#{filename}", data} | spec_acc], overlay_acc, error_acc}

              Map.has_key?(data, "overlay") ->
                {spec_acc, [{"#{filename}", data} | overlay_acc], error_acc}

              true ->
                # not openapi or overlay, ignore
                {spec_acc, overlay_acc, error_acc}
            end
          else
            false ->
              # not json or yaml file, OR doesn't contain openapi property silently ignore
              {spec_acc, overlay_acc, error_acc}

            {:error, reason} ->
              # decode error
              {spec_acc, overlay_acc, [{filename, reason} | error_acc]}
          end
        end,
        {[], [], []},
        {~c"upload.zip", zip_data}
      )

    with {:ok, {spec_data, overlay_data, []}} <- result,
         {overlays, []} <- OaiOverlay.prepare_overlays(overlay_data),
         overlayed_spec_data <- OaiOverlay.overlay(spec_data, overlays) do
      Enum.flat_map_reduce(overlayed_spec_data, [], fn {filename, data}, errors ->
        spec_name = Path.basename(filename) |> Path.rootname()

        case Spec.from_oas3(spec_name, data, Jason.encode!(data)) do
          {:ok, %Spec{cluster_id: ^cluster_id} = spec} ->
            {[spec], errors}

          {:ok, %Spec{cluster_id: _invalid_cluster_id}} ->
            {[], [{filename, "Spec is not part of cluster"} | errors]}

          {:error, reason} ->
            {[], [{filename, reason} | errors]}
        end
      end)
    else
      {:ok, {_, _, errors}} -> {[], errors}
      {_, errors} -> {[], errors}
    end
  end

  def decode(content_type, data) do
    cond do
      String.ends_with?(content_type, "json") ->
        Jason.decode(data)

      String.ends_with?(content_type, "yaml") ->
        YamlElixir.read_from_string(data)

      true ->
        {:error, "invalid content type"}
    end
  end
end
