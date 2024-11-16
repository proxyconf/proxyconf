defmodule ProxyConf.Http do
  @moduledoc """
    Expose specific functionality via HTTP
  """
  use Plug.Router
  alias ProxyConf.ConfigCache
  alias ProxyConf.LocalJwtProvider
  plug(:match)
  plug(:dispatch)

  get "/local-jwt-provider/jwks.json" do
    jwks = LocalJwtProvider.jwks()

    put_resp_header(conn, "Content-Type", "application/json")
    |> send_resp(200, Jason.encode!(jwks))
  end

  get "/local-jwt-provider/access-token" do
    conn = fetch_query_params(conn)
    token = LocalJwtProvider.token(conn.query_params)
    send_resp(conn, 200, token)
  end

  match _ do
    case conn.request_path do
      "/echo/" <> _ ->
        {:ok, data, conn} = read_body(conn)

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

      _ ->
        send_resp(conn, 404, "Not Found")
    end
  end
end
