# PingMachine

Simple demo project demonstrating a few basic OTP concepts such as Supervisors,
GenServers and Tasks.

![Ping Machine](ping_machine.png)

## Running the project

Just run the project using `iex -S mix` from the project root.

```shell
$ iex -S mix
iex(1)> {:ok, pid} = PingMachine.start_ping("192.168.0.0/24")

02:58:07.942 [info]  Started pinging all hosts in range 192.168.0.0/24
{:ok, #PID<0.212.0>}
 [info]  Successfully pinged host 192.168.0.143
 [error] Failed to ping host 192.168.0.144
 [info]  Successfully pinged host 192.168.0.145
 [error] Failed to ping host 192.168.0.146
 [info]  Successfully pinged host 192.168.0.147
 [error] Failed to ping host 192.168.0.155
 [info]  Successfully pinged host 192.168.0.156

iex(2)> PingMachine.get_successful_hosts pid
["192.168.0.212", "192.168.0.221", "192.168.0.18", "192.168.0.46",
 "192.168.0.25", "192.168.0.222", "192.168.0.132", "192.168.0.91",
 "192.168.0.89", "192.168.0.185", "192.168.0.39", "192.168.0.193",
 "192.168.0.47", "192.168.0.35", ...]

iex(3)> PingMachine.get_failed_hosts pid
["192.168.0.73", "192.168.0.123", "192.168.0.106", "192.168.0.196",
 "192.168.0.234", "192.168.0.202", "192.168.0.24", "192.168.0.201",
 "192.168.0.253", "192.168.0.238", "192.168.0.170", "192.168.0.146", ...]

 iex(4)> PingMachine.stop_ping pid
:ok
  ```
