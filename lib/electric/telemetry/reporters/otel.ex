defmodule Electric.Telemetry.Reporters.Otel do
  def child_spec(telemetry_opts, reporter_opts) do
    if get_in(telemetry_opts, [:reporters, :otel_metrics?]) do
      {__MODULE__, [telemetry_opts: telemetry_opts] ++ reporter_opts}
    end
  end

  def start_link(opts) do
    {telemetry_opts, opts} = Keyword.pop(opts, :telemetry_opts)
    reporters = telemetry_opts.reporters

    installation_id = telemetry_opts[:installation_id] || "electric_default"

    resource =
      Map.merge(
        %{instance: %{installation_id: installation_id}},
        reporters.otel_resource_attributes
      )

    start_opts = [
      metrics: Keyword.fetch!(opts, :metrics),
      export_period: reporters.otel_export_period,
      # TODO: add stack_id for stack telemetry
      resource: resource
    ]

    OtelMetricExporter.start_link(start_opts)
  end
end
