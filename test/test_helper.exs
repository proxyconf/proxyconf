Application.load(:api_fence)
{:ok, _} = Finch.start_link(name: ApiFenceFinch)
Application.ensure_all_started(:api_fence)
ExUnit.start()

