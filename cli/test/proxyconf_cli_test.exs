defmodule ProxyConf.CLITest do
  use ExUnit.Case
  doctest ProxyConf.CLI

  test "greets the world" do
    assert ProxyConf.CLI.hello() == :world
  end
end
