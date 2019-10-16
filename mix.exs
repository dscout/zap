defmodule Zap.MixProject do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      app: :zap,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Hex
      package: package(),
      description: "Native ZIP archive creation with chunked input and output.",

      # Dialyzer
      dialyzer: [
        flags: [:error_handling, :race_conditions, :underspecs]
      ],

      # Docs
      name: "Zap",
      docs: [
        main: "Zap",
        source_ref: "v#{@version}",
        source_url: "https://github.com/dscout/zap"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def package do
    [
      maintainers: ["Parker Selbert"],
      licenses: ["Apache-2.0"],
      links: %{github: "https://github.com/dscout/zap"}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.0", only: [:test, :dev], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:test, :dev], runtime: false},
      {:ex_doc, "~> 0.20", only: [:dev], runtime: false},
      {:stream_data, "~> 0.4", only: [:test]}
    ]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "credo --strict",
        "test --raise",
        "dialyzer"
      ]
    ]
  end
end
