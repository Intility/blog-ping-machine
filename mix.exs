defmodule PingMachine.MixProject do
  use Mix.Project

  def project do
    [
      app: :ping_machine,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {PingMachine.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:net_address, "~> 0.3.0"}
    ]
  end
end
