defmodule ProxyConf.CommonsTest do
  use ExUnit.Case
  doctest ProxyConf.Commons

  test "greets the world" do
    assert ProxyConf.Commons.hello() == :world
  end
end
