defmodule ProxyConf.Hurl do
  use ExUnit.Case, async: true

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ProxyConf.Repo)
    # Setting the shared mode must be done only after checkout
    Ecto.Adapters.SQL.Sandbox.mode(ProxyConf.Repo, {:shared, self()})
  end

  test "run hurl suite" do
    ProxyConf.LocalCA.server_cert("exunit-good")
    ProxyConf.LocalCA.server_cert("exunit-bad")

    {res, rc} =
      System.shell("./examples/run.sh", env: [{"EXUNIT_RUNNER", "true"}])

    IO.puts(res)
    assert rc == 0
  end
end
