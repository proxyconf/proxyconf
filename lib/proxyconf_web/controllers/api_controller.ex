defmodule ProxyConfWeb.ApiController do
  use ProxyConfWeb, :controller
  alias ProxyConf.Db
  alias ProxyConf.Spec

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
         {:ok, {specs, []}} <- iterate_zip_contents(data, cluster_id),
         :ok <- Db.create_or_update(specs, sync: cluster_id) do
      send_resp(conn, 200, "OK")
    else
      {:error, reason} ->
        send_resp(conn, 400, "Bad Request: #{reason}")
        |> halt

      {:ok, {_specs, errors}} ->
        error_summary =
          Enum.map(errors, fn {filename, reason} ->
            "- #{filename}: #{reason}"
          end)
          |> Enum.join("\n")

        send_resp(conn, 400, "Bad Request:\n#{error_summary}")
        |> halt
    end
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
    :zip.foldl(
      fn filename, _fileinfo_fn, filedata_fn, {spec_acc, error_acc} ->
        ext = Path.extname(filename)
        spec_name = Path.basename(filename) |> Path.rootname()
        IO.inspect(spec_name, label: "cluster: #{cluster_id}")

        with true <- ext in [".json", ".yaml"],
             data <- filedata_fn.(),
             {:ok, spec} <- decode(ext, data),
             true <- Map.has_key?(spec, "openapi"),
             {:ok, %Spec{cluster_id: ^cluster_id} = spec} <- Spec.from_oas3(spec_name, spec, data) do
          {[spec | spec_acc], error_acc}
        else
          false ->
            # not json or yaml file, OR doesn't contain openapi property silently ignore
            {spec_acc, error_acc}

          {:ok, %Spec{cluster_id: _invalid_cluster_id}} ->
            {spec_acc, [{filename, "Spec is not part of cluster"} | error_acc]}

          {:error, reason} ->
            # decode error
            {spec_acc, [{filename, reason} | error_acc]}
        end
      end,
      {[], []},
      {~c"upload.zip", zip_data}
    )
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
