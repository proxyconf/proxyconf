defmodule ProxyConfWeb.OAuthController do
  use ProxyConfWeb, :controller

  def jwks(conn, _params) do
    jwks = ProxyConf.OAuth.JwtSigner.jwks()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(jwks))
  end

  def issue_token(conn, _params) do
    conn = fetch_query_params(conn)
    config = Application.fetch_env!(:proxyconf, ExOauth2Provider)
    # We have to intercept the Ecto repo, to be able to store the client secret as
    # a hash instead of plain text.
    config_intercepted_repo = Keyword.put(config, :repo, __MODULE__)

    case ExOauth2Provider.Token.grant(conn.query_params, config_intercepted_repo) do
      {:ok, access_token} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(access_token))

      {:error, error, http_status} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(http_status, Jason.encode!(error))
    end
  end

  def create_cluster(conn, %{"cluster_name" => cluster_name}) do
    case ProxyConf.OAuth.create_oauth_app_for_cluster(cluster_name) do
      {:ok, resp} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(resp))

      {:error, error} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(error))
    end
  end

  def rotate_cluster_secret(conn, _params) do
    access_token =
      ExOauth2Provider.Plug.current_access_token(conn) |> ProxyConf.Repo.preload([:application])

    case ProxyConf.OAuth.create_oauth_app_for_cluster(access_token.application.name,
           rotate_secret: true
         ) do
      {:ok, resp} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(resp))

      {:error, error} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(error))
    end
  end

  def get_by(ProxyConf.OAuth.Application, uid: uid, secret: secret) do
    ProxyConf.OAuth.get_application(uid, secret)
  end

  defdelegate all(q), to: ProxyConf.Repo
  defdelegate insert(q), to: ProxyConf.Repo
end
