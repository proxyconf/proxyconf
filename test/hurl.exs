defmodule ProxyConf.Hurl do
  use ExUnit.Case, async: true

  test "run hurl suite" do
    System.cmd("pwd", []) |> IO.inspect()

    {res, rc} =
      System.shell("./examples/run.sh", [])

    IO.puts(res)
    assert rc == 0
  end
end
