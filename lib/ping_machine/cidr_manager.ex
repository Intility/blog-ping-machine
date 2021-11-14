defmodule PingMachine.CIDRManager do
  @moduledoc false

  use GenServer

  require Logger
  require IP.Subnet

  def start_link(cidr) when IP.Subnet.is_subnet(cidr) do
    GenServer.start_link(__MODULE__, cidr, name: :"#{__MODULE__}-#{IP.Subnet.to_string(cidr)}")
  end

  def init(cidr) when IP.Subnet.is_subnet(cidr) do
    {:ok, pid} = Task.Supervisor.start_link(name: :"PingSupervisor-#{IP.Subnet.to_string(cidr)}")

    # Send a message to our self that we should start pinging at once!
    Process.send(self(), :start_ping, [])
    {:ok, %{supervisor: pid, cidr: cidr, tasks: MapSet.new()}}
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
      Task.Supervisor.async_nolink(:"PingSupervisor-#{IP.Subnet.to_string(state.cidr)}", fn ->
        # Pretends to send a ping request by sleeping some time and then
        # randomly selecting a return value for the task. Fails approx 1/3 tasks.

        Enum.random(100..1000) |> Process.sleep()
        Enum.random([:ok, :ok, :error])
      end)

    # Register the task in the GenServer state, so that we can track which
    # tasks responded with a successful ping request, and which didn't.
    {:noreply,
     %{state | tasks: MapSet.put(state.tasks, %{host: host, status: :pending, task: task})}}
  end

  def handle_info(:start_ping, state) do
    Enum.map(state.cidr, fn host ->
      GenServer.cast(
        :"#{__MODULE__}-#{IP.Subnet.to_string(state.cidr)}",
        {:task, IP.to_string(host)}
      )
    end)

    {:noreply, state}
  end

  # The task completed successfully
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

  # The task failed
  def handle_info({ref, :error}, state) do
    task =
      Enum.find(state.tasks, fn %{host: _host, status: _status, task: %{ref: r}} -> r == ref end)

    Logger.error("Failed to ping host #{task.host}")

    updated_tasks =
      MapSet.delete(state.tasks, task)
      |> MapSet.put(Map.put(task, :status, :failed))

    {:noreply, %{state | tasks: updated_tasks}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end
end
