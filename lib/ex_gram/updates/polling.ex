defmodule ExGram.Updates.Polling do
  use GenServer
  # require Logger

  def start_link({:bot, pid, :token, token}) do
    # Logger.debug "START WORKER"
    # TODO: Use name
    GenServer.start_link(__MODULE__, {:ok, pid, token})
  end

  def init({:ok, pid, token}) do
    # Clean webhook
    ExGram.delete_webhook(token: token)

    Process.send_after(self(), {:fetch, :update_id, -1}, 1000)
    {:ok, {pid, token}}
  end

  def handle_cast({:fetch, :update_id, _} = m, state), do: handle_info(m, state)

  def handle_info({:fetch, :update_id, uid}, {pid, token} = state) do
    # Logger.debug "GetUpdates!"
    # TODO: If timeout, keep going!
    case ExGram.get_updates(limit: 100, offset: uid, timeout: 30000, token: token) do
      {:ok, updates} ->
        Enum.map(updates, &GenServer.call(pid, {:update, &1}))

        nid = extract_last_pid(uid, updates)

        send(self(), {:fetch, :update_id, nid + 1})

      {:error, error} ->
        Process.send(self(), {:fetch, :update_id, uid}, [:nosuspend])
    end

    {:noreply, state}
  rescue
    # If timeout don't wait?
    Maxwell.Error ->
      Process.send_after(self(), {:fetch, :update_id, uid}, 1)
  end

  defp extract_last_pid(actual, []), do: actual

  defp extract_last_pid(actual, [u | us]) do
    au = u.update_id

    extract_last_pid(max(au, actual), us)
  end
end
