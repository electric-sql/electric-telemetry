defmodule Electric.Telemetry.Reporters.Prometheus do
  def child_spec(telemetry_opts, reporter_opts) do
    if get_in(telemetry_opts, [:reporters, :prometheus?]) do
      reporter_opts
    end
  end

  def start_link(opts) do
    TelemetryMetricsPrometheus.Core.start_link(opts)
  end
end
