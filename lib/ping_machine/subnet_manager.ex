defmodule PingMachine.SubnetManager do
  @moduledoc false

  use GenServer

  require Logger
  require IP.Subnet

  def start_link(subnet) when IP.Subnet.is_subnet(subnet) do
    GenServer.start_link(__MODULE__, subnet, name: via_tuple(IP.Subnet.to_string(subnet)))
  end

  def init(subnet) do
    # Send a message to our self that we should start pinging at once!
    Process.send(self(), :start_ping, [])
    {:ok, %{subnet: subnet, tasks: MapSet.new()}}
  end

  def handle_call(:successful_hosts, _from, state) do
    success =
      Enum.filter(state.tasks, fn task -> task.status == :success end)
      |> Enum.map(fn task -> task.host end)

    {:reply, success, state}
  end

  def handle_call(:failed_hosts, _from, state) do
    success =
      Enum.filter(state.tasks, fn task -> task.status == :failed end)
      |> Enum.map(fn task -> task.host end)

    {:reply, success, state}
  end

  def handle_cast({:task, host}, state) do
    task =
      Task.Supervisor.async_nolink(
        PingMachine.TaskSupervisor,
        fn ->
          # Pretends to send a ping request by sleeping some time and then
          # randomly selecting a return value for the task. Fails approx 1/3 tasks.

          Enum.random(100..1000) |> Process.sleep()
          Enum.random([:ok, :ok, :error])
        end
      )

    # Register the task in the GenServer state, so that we can track which
    # tasks responded with a successful ping request, and which didn't.
    {:noreply,
     %{state | tasks: MapSet.put(state.tasks, %{host: host, status: :pending, task: task})}}
  end

  def handle_info(:start_ping, state) do
    Enum.map(state.subnet, fn host ->
      GenServer.cast(
        via_tuple(IP.Subnet.to_string(state.subnet)),
        {:task, IP.to_string(host)}
      )
    end)

    {:noreply, state}
  end

  # The ping request succeeded
  def handle_info({ref, :ok}, state) do
    task =
      Enum.find(state.tasks, fn %{host: _host, status: _status, task: %{ref: r}} -> r == ref end)

    Logger.info("Successfully pinged host #{task.host}")

    # We don't care about the :DOWN message from the task anymore, so demonitor
    # and flush it.
    Process.demonitor(ref, [:flush])

    updated_tasks =
      MapSet.delete(state.tasks, task)
      |> MapSet.put(Map.put(task, :status, :success))

    {:noreply, %{state | tasks: updated_tasks}}
  end

  # The ping request failed
  def handle_info({ref, :error}, state) do
    task =
      Enum.find(state.tasks, fn %{host: _host, status: _status, task: %{ref: r}} -> r == ref end)

    Logger.error("Failed to ping host #{task.host}")

    Process.demonitor(ref, [:flush])

    updated_tasks =
      MapSet.delete(state.tasks, task)
      |> MapSet.put(Map.put(task, :status, :failed))

    {:noreply, %{state | tasks: updated_tasks}}
  end

  # The task itself failed
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  defp via_tuple(name), do: {:via, Registry, {PingMachine.Registry, name}}
end
