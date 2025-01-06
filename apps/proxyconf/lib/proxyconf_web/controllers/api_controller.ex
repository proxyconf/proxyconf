defmodule ProxyConfWeb.ApiController do
  use ProxyConfWeb, :controller
  alias ProxyConf.Db
  alias ProxyConf.Commons.Spec
  alias ProxyConf.Api.DbSpec
  require Logger

  def get_spec(conn, %{"spec_name" => spec_name} = _params) do
    access_token =
      ExOauth2Provider.Plug.current_access_token(conn) |> ProxyConf.Repo.preload([:application])

    cluster_id = access_token.application.name
    conn = fetch_query_params(conn)

    case Db.get_spec(cluster_id, spec_name) do
      %DbSpec{data: data} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, data)

      nil ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, JSON.encode!(%{message: "requested spec doesn't exist"}))
    end
  end

  def get_specs(conn, _params) do
    access_token =
      ExOauth2Provider.Plug.current_access_token(conn) |> ProxyConf.Repo.preload([:application])

    cluster_id = access_token.application.name
    conn = fetch_query_params(conn)

    spec_ids = Db.get_spec_ids(cluster_id)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, JSON.encode!(%{cluster: cluster_id, spec_ids: spec_ids}))
  end

  def delete_spec(conn, %{"spec_name" => spec_name} = _params) do
    access_token =
      ExOauth2Provider.Plug.current_access_token(conn) |> ProxyConf.Repo.preload([:application])

    cluster_id = access_token.application.name

    case Db.delete_spec(cluster_id, spec_name) do
      :ok ->
        send_resp(conn, 200, "OK")

      {:error, :not_found} ->
        send_resp(conn, 400, "Spec is not part of cluster")
        |> halt
    end
  end

  def upload_spec(conn, %{"spec_name" => spec_name} = _params) do
    access_token =
      ExOauth2Provider.Plug.current_access_token(conn) |> ProxyConf.Repo.preload([:application])

    cluster_id = access_token.application.name
    conn = fetch_query_params(conn)

    with {:ok, data, conn} <- read_all_body(conn),
         [content_type | _] <- get_req_header(conn, "content-type"),
         qs_params <- Enum.map(conn.query_params, fn {k, v} -> {String.to_charlist(k), v} end),
         {:ok, %Spec{cluster_id: ^cluster_id} = spec} <-
           Spec.to_spec(spec_name, data, content_type, qs_params),
         _ <-
           Logger.info(
             cluster: cluster_id,
             api_id: spec.api_id,
             message: "Valid spec uploaded for #{spec.api_url}"
           ),
         :ok <- Db.create_or_update_specs([spec]) do
      send_resp(conn, 200, "OK")
    else
      {:ok, %Spec{cluster_id: _invalid_cluster_id}} ->
        send_resp(conn, 400, "Spec is not part of cluster")
        |> halt

      {:error, reason} ->
        Logger.warning(reason)

        send_resp(conn, 400, "Bad Request: #{reason}")
        |> halt
    end
  end

  def upload_bundle(conn, _params) do
    access_token =
      ExOauth2Provider.Plug.current_access_token(conn) |> ProxyConf.Repo.preload([:application])

    cluster_id = access_token.application.name

    conn = fetch_query_params(conn)

    with {:ok, data, conn} <- read_all_body(conn),
         qs_params <- Enum.map(conn.query_params, fn {k, v} -> {String.to_charlist(k), v} end),
         {specs, []} <- iterate_zip_contents(data, qs_params, cluster_id),
         :ok <- Db.create_or_update_specs(specs, sync: cluster_id) do
      send_resp(conn, 200, "OK")
    else
      {:error, reason} ->
        Logger.warning(reason)

        send_resp(conn, 400, "Bad Request: #{reason}")
        |> halt

      {_specs, [{_filename, _reason} | _] = errors} ->
        error_summary =
          Enum.map(errors, fn {filename, reason} ->
            "- #{filename}: #{reason}"
          end)
          |> Enum.join("\n")

        Logger.warning(error_summary)

        send_resp(conn, 400, "Bad Request:\n#{error_summary}")
        |> halt

      {_, zip_error} ->
        Logger.warning(zip_error)

        send_resp(conn, 400, "Bad Request:\n#{zip_error}")
        |> halt
    end
  end

  @doc """
  The secret can be referenced using %SECRET_NAME% inside the config items
  that allow dynamic secrets, e.g. upstream credential injection
  """
  def create_or_update_secret(conn, %{"secret_name" => secret_name} = _params) do
    access_token =
      ExOauth2Provider.Plug.current_access_token(conn) |> ProxyConf.Repo.preload([:application])

    cluster_id = access_token.application.name
    conn = fetch_query_params(conn)

    with {:ok, data, conn} <- read_all_body(conn),
         :ok <- Db.create_or_update_secret(cluster_id, secret_name, String.trim(data)) do
      send_resp(conn, 200, "OK")
    else
      {:error, reason} ->
        Logger.warning(reason)

        send_resp(conn, 400, "Bad Request: #{reason}")
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
        request_path: conn.request_path,
        method: conn.method
      }
      |> JSON.encode!()

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

  defp iterate_zip_contents(zip_data, query_params, cluster_id) do
    zip_spec_provider = fn iterator_fn, iterator_acc ->
      :zip.foldl(
        fn filename, _fileinfo_fn, filedata_fn, acc ->
          iterator_fn.("#{filename}", filedata_fn, acc)
        end,
        iterator_acc,
        {~c"upload.zip", zip_data}
      )
    end

    Spec.to_specs(zip_spec_provider, cluster_id, query_params)
  end
end
