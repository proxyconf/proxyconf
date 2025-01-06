defmodule ProxyConf.Cron do
  @moduledoc """
  A Quantum Scheduler to schedule external jobs.
  This is useful if e.g. OpenAPI specifications, Certificates have to be 
  periodically checked/fetched.
  """
  use Quantum, otp_app: :proxyconf
  require Logger

  def to_config({:error, :enoent}), do: []

  def to_config({:ok, crontab}) do
    crontab
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(fn crontab ->
      crontab == "" or String.starts_with?(crontab, "#")
    end)
    |> Enum.map(fn crontab ->
      String.split(crontab, " ")
      |> split_crontab_cmd()
    end)
  end

  defp split_crontab_cmd(crontab) do
    split_crontab_cmd(crontab, [])
  end

  defp split_crontab_cmd(["*" <> _ = i | rest], acc), do: split_crontab_cmd(rest, [i | acc])
  defp split_crontab_cmd(["@" <> _ = i | rest], acc), do: split_crontab_cmd(rest, [i | acc])

  defp split_crontab_cmd([i | rest], acc) when i >= "0" and i <= "59",
    do: split_crontab_cmd(rest, [i | acc])

  defp split_crontab_cmd(cmd, interval) do
    {Enum.reverse(interval) |> Enum.join(" "), {__MODULE__, :run, [Enum.join(cmd, " ")]}}
  end

  def run(cmd) do
    case System.shell(cmd, stderr_to_stdout: true) do
      {res, 0} ->
        Logger.info(res)

      {res, rc} ->
        Logger.error(res <> " - Cron job exited with #{rc}")
    end
  end
end
