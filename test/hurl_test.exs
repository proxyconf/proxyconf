defmodule ProxyConf.Hurl do
  use ExUnit.Case, async: true

  test "run hurl suite" do
    ProxyConf.LocalCA.server_cert("exunit-good")
    ProxyConf.LocalCA.server_cert("exunit-bad")

    {res, rc} =
      System.shell("./examples/run.sh", env: [{"EXUNIT_RUNNER", "true"}])

    IO.puts(res)
    assert rc == 0
  end
end
