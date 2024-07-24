defmodule ProxyConfTest do
  use ExUnit.Case
  doctest ProxyConf
  doctest ProxyConf.MapTemplate
  doctest ProxyConf.MapPatch

  test "greets the world" do
    assert ProxyConf.hello() == :world
  end

  #  test "generate routes from openapi spec" do
  #    {:ok, spec} = YamlElixir.read_from_file("test/oas3/petstore.yaml")
  #
  #    ProxyConf.Types.VHost.oas3_to_vhosts([spec])
  #    |> IO.inspect()
  #  end
end
