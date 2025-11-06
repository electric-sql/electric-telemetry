defmodule Electric.Telemetry.Reporters.Statsd do
  import Telemetry.Metrics

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

  def stack_metrics(stack_id) do
    for_stack = fn metadata -> metadata[:stack_id] == stack_id end

    [
      summary("plug.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond},
        keep: for_stack
      ),
      summary("plug.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond},
        keep: for_stack
      ),
      summary("electric.shape_cache.create_snapshot_task.stop.duration",
        unit: {:native, :millisecond},
        keep: for_stack
      ),
      summary("electric.storage.make_new_snapshot.stop.duration",
        unit: {:native, :millisecond},
        keep: for_stack
      ),
      summary("electric.querying.stream_initial_data.stop.duration",
        unit: {:native, :millisecond},
        keep: for_stack
      ),
      last_value("electric.connection.consumers_ready.duration",
        unit: {:native, :millisecond},
        keep: for_stack
      ),
      last_value("electric.connection.consumers_ready.total", keep: for_stack),
      last_value("electric.connection.consumers_ready.before_recovery", keep: for_stack)
    ]
    |> add_instance_id_tag()
  end

  defp add_instance_id_tag(metrics) do
    Enum.map(metrics, fn metric -> Map.update!(metric, :tags, &[:instance_id | &1]) end)
  end
end
