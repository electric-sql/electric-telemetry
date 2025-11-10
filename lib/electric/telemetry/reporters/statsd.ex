use Electric.Telemetry

with_telemetry Telemetry.Metrics do
  defmodule Electric.Telemetry.Reporters.Statsd do
    def child_spec(telemetry_opts, reporter_opts) do
      if host = get_in(telemetry_opts, [:reporters, :statsd_host]) do
        {__MODULE__,
         [host: host, global_tags: [instance_id: telemetry_opts.instance_id] ++ reporter_opts]}
      end
    end

    def start_link(opts) do
      host = Keyword.fetch!(opts, :host)
      global_tags = Keyword.fetch!(opts, :global_tags)
      metrics = Keyword.fetch!(opts, :metrics)

      TelemetryMetricsStatsd.start_link(
        host: host,
        formatter: :datadog,
        global_tags: global_tags,
        metrics: metrics
      )
    end

    def add_instance_id_tag(metrics) do
      Enum.map(metrics, fn metric -> Map.update!(metric, :tags, &[:instance_id | &1]) end)
    end
  end
end
