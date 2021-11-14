defmodule PingMachineTest do
  use ExUnit.Case
  doctest PingMachine

  test "passing a valid subnet returns an ok tuple" do
    assert {:ok, pid} = PingMachine.start_ping("192.168.0.0/24")
    assert :ok = PingMachine.stop_ping(pid)
  end
end
