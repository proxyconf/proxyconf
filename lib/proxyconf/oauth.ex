defmodule ProxyConf.OAuth do
  def create_oauth_app_for_cluster(
        cluster_name,
        opts \\ []
      ) do
    uid = cluster_name
    redirect_uri = Keyword.get(opts, :redirect_uri, "https://localhost:8443")
    rotate_secret = Keyword.get(opts, :rotate_secret, false)

    # OAuth Flows that use HTTP Redirections aren't supported, but the redirect_url is still required
    case get_oauth_name_for_cluster(cluster_name) do
      app when is_nil(app) or rotate_secret ->
        secret = gen_secret()
        app = app || %ProxyConf.OAuth.Application{}

        ExOauth2Provider.Applications.Application.changeset(app, %{
          name: cluster_name,
          redirect_uri: redirect_uri,
          uid: uid,
          secret: Argon2.hash_pwd_salt(secret)
        })
        |> ProxyConf.Repo.insert_or_update!()

        {:ok, %{client_id: uid, client_secret: secret}}

      _app ->
        {:error, %{message: "OAuth2 Configuration for cluster already exists"}}
    end
  end

  def get_oauth_name_for_cluster(cluster_name) do
    case ProxyConf.Repo.get_by(ProxyConf.OAuth.Application, name: cluster_name) do
      nil -> nil
      app -> app
    end
  end

  def get_application(client_id, client_secret) do
    case ProxyConf.Repo.get_by(ProxyConf.OAuth.Application, uid: client_id) do
      %ProxyConf.OAuth.Application{secret: hashed_secret} = app ->
        if Argon2.verify_pass(client_secret, hashed_secret) do
          %ProxyConf.OAuth.Application{app | secret: "***REDACTED***"}
        else
          nil
        end

      nil ->
        nil
    end
  end

  def gen_secret(length \\ 64) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode64(padding: false)
    |> binary_part(0, length)
    # "+" has to be encoded in %2b for some HTTP clients, let's remove + for better user experience
    |> String.replace("+", "-")
    |> String.replace_trailing("/", "-")
  end
end
