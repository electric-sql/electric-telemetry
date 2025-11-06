defmodule Electric.Telemetry.Reporters.Otel do
  def child_spec(telemetry_opts, reporter_opts) do
    if get_in(telemetry_opts, [:reporters, :otel_metrics?]) do
      {__MODULE__, Enum.into(reporter_opts, telemetry_opts)}
    end
  end

  def start_link(telemetry_opts) do
    OtelMetricExporter.start_link(
      metrics: Keyword.fetch!(telemetry_opts, :metrics),
      export_period: get_in(telemetry_opts, [:reporters, :otel_export_period]),
      # TODO: add stack_id for stack telemetry
      resource:
        Map.merge(
          %{
            instance: %{
              installation_id: Map.get(telemetry_opts, :installation_id, "electric_default")
            }
          },
          get_in(telemetry_opts, [:reporters, :otel_resource_attributes])
        )
    )
  end
end
