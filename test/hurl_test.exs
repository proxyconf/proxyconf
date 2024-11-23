defmodule ProxyConf.Hurl do
  use ExUnit.Case, async: true

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ProxyConf.Repo)
    # Setting the shared mode must be done only after checkout
    Ecto.Adapters.SQL.Sandbox.mode(ProxyConf.Repo, {:shared, self()})

    {:ok, %{client_id: client_id, client_secret: client_secret}} =
      ProxyConf.OAuth.create_oauth_app_for_cluster("exunit-cluster", rotate: true)

    {:ok, %{client_id: client_id_other, client_secret: client_secret_other}} =
      ProxyConf.OAuth.create_oauth_app_for_cluster("exunit-cluster-other", rotate: true)

    # ignore result above, as it's possible that the cluster config already
    # exists, in this case we use the already existing config
    %{
      client_id: client_id,
      client_secret: client_secret,
      client_id_other: client_id_other,
      client_secret_other: client_secret_other,
      envoy_cluster: "exunit-cluster"
    }
  end

  test "run hurl suite", config do
    ProxyConf.LocalCA.server_cert("exunit-good")
    ProxyConf.LocalCA.server_cert("exunit-bad")

    {res, rc} =
      System.shell("./examples/run.sh",
        env: [
          {"EXUNIT_RUNNER", "true"},
          {"OAUTH_CLIENT_ID", config.client_id},
          {"OAUTH_CLIENT_SECRET", config.client_secret},
          # the *_OTHER Env Vars are used to be able to test access with 'invalid' JWT credentials
          {"OAUTH_CLIENT_ID_OTHER", config.client_id_other},
          {"OAUTH_CLIENT_SECRET_OTHER", config.client_secret_other},
          {"ENVOY_CLUSTER", config.envoy_cluster}
        ]
      )

    IO.puts(res)
    assert rc == 0
  end
end
