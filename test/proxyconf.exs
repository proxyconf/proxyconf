defmodule ProxyConfTest do
  use ExUnit.Case
  doctest ProxyConf
  doctest ProxyConf.MapTemplate
  doctest ProxyConf.MapPatch

  test "greets the world" do
    assert ProxyConf.hello() == :world
  end
end
