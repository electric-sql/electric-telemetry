defmodule Electric.Telemetry.MixProject do
  use Mix.Project

  def project do
    [
      app: :electric_telemetry,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :os_mon, :runtime_tools],
      mod: {Electric.Telemetry.Application, []}
    ]
  end

  defp deps do
    [
      # {:opentelemetry_exporter, "~> 1.9"},
      # {:otel_metric_exporter, "~> 0.3.11"},
      # Temporarily use the latest `main` version of otel_metric_exporter for testing
      {:otel_metric_exporter,
       github: "electric-sql/elixir-otel-metric-exporter",
       ref: "abad392a9b4c39109ab6989e2b9373c5d1403a2c"},
      {:req, "~> 0.5"},
      {:telemetry, "~> 1.3"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:telemetry_metrics_statsd, "~> 0.7"},
      {:telemetry_poller, "~> 1.3"}
    ]
  end
end
