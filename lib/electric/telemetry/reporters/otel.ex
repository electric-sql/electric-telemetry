defmodule Electric.Telemetry.Reporters.Otel do
  def child_spec(telemetry_opts, reporter_opts) do
    IO.puts("Otel.child_spec/2")

    if get_in(telemetry_opts, [:reporters, :otel_metrics?]) do
      otel_opts = Map.get(telemetry_opts, :otel_opts, [])

      %{
        id: __MODULE__,
        start: {OtelMetricExporter, :start_link, [otel_opts ++ reporter_opts]},
        type: :worker
      }
    end
  end
end
