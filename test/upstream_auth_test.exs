defmodule ProxyConf.UpstreamAuthTest do
  use ExUnit.Case, async: true
  use ProxyConf.TestSupport.Oas3Case
  @tag :wip
  oas3spec("test/oas3/upstream-auth.yaml", ctx)
end
