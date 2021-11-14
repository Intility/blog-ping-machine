defmodule PingMachine do
  @moduledoc false

  require IP.Subnet
  require Logger

  def start_ping(cidr) when is_binary(cidr) do
    with {:ok, cidr} <- IP.Subnet.from_string(cidr),
         {:ok, pid} <- start_worker(cidr) do
      Logger.info("Started pinging all hosts in range #{IP.Subnet.to_string(cidr)}")
      {:ok, pid}
    else
      {:error, {:already_started, pid}} ->
        Logger.warn("Already running the #{cidr} range")
        {:ok, pid}

      {:error, :einval} = reply ->
        Logger.error("#{cidr} is not a valid CIDR range")
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

  defp start_worker(cidr) when IP.Subnet.is_subnet(cidr) do
    DynamicSupervisor.start_child(
      PingMachine.PingSupervisor,
      {PingMachine.CIDRManager, cidr}
    )
  end
end
