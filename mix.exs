defmodule JavaMonitor.MixProject do
  use Mix.Project

  def project do
    [
      app: :java_monitor,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {JavaMonitor.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:table_rex, "~> 3.1.1"}  # For pretty terminal tables (optional)
    ]
  end

  defp escript do
    [
      main_module: JavaMonitor.CLI,
      name: "java_monitor"
    ]
  end
end
