defmodule ProxyConfWeb.EchoSocket do
  @behaviour Phoenix.Socket.Transport
  require Logger

  def child_spec(_opts) do
    # We won't spawn any process, so let's ignore the child spec
    :ignore
  end

  def connect(state) do
    # Callback to retrieve relevant data from the connection.
    # The map contains options, params, transport and endpoint keys.
    Logger.debug("New Websocket Connection #{inspect(self())}")

    {:ok, state}
  end

  def init(state) do
    # Now we are effectively inside the process that maintains the socket.
    {:ok, state}
  end

  def handle_in({text, _opts}, state) do
    Logger.debug("Websocket #{inspect(self())} received message #{inspect(text)}")
    {:reply, :ok, {:text, text}, state}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  def terminate(reason, _state) do
    Logger.debug("Websocket #{inspect(self())} terminated message #{inspect(reason)}")
    :ok
  end
end
