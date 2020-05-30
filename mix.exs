defmodule ExCop.MixProject do
  use Mix.Project

  def project(),
    do: [
      app: :ex_cop,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [] ++ Mix.compilers(),
      test_coverage: [tool: ExCoveralls],
      aliases: aliases()
    ]

  def application(),
    do: [
      extra_applications: [:logger]
    ]

  defp aliases(),
    do: []

  defp elixirc_paths(:test),
    do: ["lib", "test/support"]

  defp elixirc_paths(_),
    do: ["lib"]
end
