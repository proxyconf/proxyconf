defmodule CronTest do
  use ExUnit.Case, async: false

  test "Parse Crontab" do
    cmd = {ProxyConf.Cron, :run, ["my command"]}

    assert [{"* * * * *", cmd}, {"@daily", cmd}, {"* */10", cmd}, {"1 1 1 1 1", cmd}] ==
             ProxyConf.Cron.to_config(
               {:ok,
                """
                      # a comment
                      * * * * * my command

                      @daily my command
                      
                      * */10 my command

                      1 1 1 1 1 my command
                """}
             )
  end
end
