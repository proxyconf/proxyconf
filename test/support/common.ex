defmodule ProxyConf.TestSupport.Common do
  @moduledoc false
  require Logger

  def http_req(method, url, body \\ nil, headers \\ [], finch \\ ProxyConfFinch) do
    request = Finch.build(method, url, [{"Host", "localhost"} | headers], body)

    case Finch.request!(request, finch) do
      %Finch.Response{status: status} = response when status > 400 ->
        proc_dict_key = {__MODULE__, :http_req}
        hash = :erlang.phash2({request, response})

        if Process.get(proc_dict_key) != hash do
          Logger.error(request: request, response: response)
          Process.put(proc_dict_key, hash)
        end

        response

      response ->
        response
    end
  end

  def parse_oas3(file) do
    {:ok, spec} = ProxyConf.ConfigCache.parse_spec_file(file)
    spec
  end
end
