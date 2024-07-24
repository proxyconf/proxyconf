defmodule ApiFenceTest do
  use ExUnit.Case
  doctest ApiFence
  doctest ApiFence.MapTemplate
  doctest ApiFence.MapPatch

  test "greets the world" do
    assert ApiFence.hello() == :world
  end

  #  test "generate routes from openapi spec" do
  #    {:ok, spec} = YamlElixir.read_from_file("test/oas3/petstore.yaml")
  #
  #    ApiFence.Types.VHost.oas3_to_vhosts([spec])
  #    |> IO.inspect()
  #  end
end
