defmodule ExCop.MixProject do
  use Mix.Project

  def project(),
    do: [
      app: :ex_cop,
      name: "ExCop",
      description: "A simple DSL to help writting policies.",
      source_url: "https://github.com/tableturn/ex_cop",
      homepage_url: "https://github.com/tableturn/ex_cop",
      docs: [extras: ~w(README.md)],
      version: "0.1.2",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [] ++ Mix.compilers(),
      dialyzer: [
        plt_add_deps: :transitive,
        plt_add_apps: [:mix]
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env:
        cli_env_for(
          :test,
          ~w(coveralls coveralls.detail coveralls.html coveralls.json coveralls.post)
        ),
      package: package(),
      deps: deps()
    ]

  def application(),
    do: [
      extra_applications: [:logger]
    ]

  defp cli_env_for(env, tasks),
    do: Enum.reduce(tasks, [], &Keyword.put(&2, :"#{&1}", env))

  defp package(),
    do: [
      name: "ex_cop",
      files: ["lib", "mix.exs", "README*"],
      maintainers: ["Pierre Martin"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/tableturn/ex_cop"}
    ]

  defp elixirc_paths(:test),
    do: ["lib", "test/support"]

  defp elixirc_paths(_),
    do: ["lib"]

  defp deps(),
    # Dev / Test only.
    do: [
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
end
