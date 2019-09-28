defmodule Zap.MixProject do
  use Mix.Project

  def project do
    [
      app: :zap,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Dialyzer
      dialyzer: [
        flags: [:error_handling, :race_conditions, :underspecs]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      {:stream_data, "~> 0.4", only: [:test]}
    ]
  end
end
