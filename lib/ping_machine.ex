defmodule PingMachine do
  @moduledoc false

  require IP.Subnet
  require Logger

  def start_ping(subnet) when is_binary(subnet) do
    with {:ok, subnet} <- IP.Subnet.from_string(subnet),
         {:ok, pid} <- start_worker(subnet) do
      Logger.info("Started pinging all hosts in range #{IP.Subnet.to_string(subnet)}")
      {:ok, pid}
    else
      {:error, {:already_started, pid}} ->
        Logger.warn("Already running the #{subnet} range")
        {:ok, pid}

      {:error, :einval} = reply ->
        Logger.error("#{subnet} is not a valid subnet range")
        reply
    end
  end

  def get_successful_hosts(pid) when is_pid(pid) do
    GenServer.call(pid, :successful_hosts)
  end

  def get_failed_hosts(pid) when is_pid(pid) do
    GenServer.call(pid, :failed_hosts)
  end

  def stop_ping(pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(PingMachine.PingSupervisor, pid)
  end

  defp start_worker(subnet) when IP.Subnet.is_subnet(subnet) do
    DynamicSupervisor.start_child(
      PingMachine.PingSupervisor,
      {PingMachine.SubnetManager, subnet}
    )
  end
end
