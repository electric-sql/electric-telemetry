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
      {:otel_metric_exporter, "~> 0.4.0"},
      {:req, "~> 0.5"},
      {:telemetry, "~> 1.3"},
      {:telemetry_metrics, "~> 1.1"},
      {:telemetry_metrics_prometheus_core, "~> 1.2"},
      {:telemetry_metrics_statsd, "~> 0.7"},
      {:telemetry_poller, "~> 1.3"}
    ]
  end
end
