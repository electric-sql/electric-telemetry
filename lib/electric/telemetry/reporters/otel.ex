defmodule Electric.Telemetry.Reporters.Otel do
  import Telemetry.Metrics

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

  def application_metrics do
    # TODO: externalize the Prometheus call
    [
      last_value("process.memory.total", tags: [:process_type], unit: :byte),
      last_value("system.load_percent.avg1"),
      last_value("system.load_percent.avg5"),
      last_value("system.load_percent.avg15"),
      last_value("system.memory_percent.free_memory"),
      last_value("system.memory_percent.available_memory"),
      last_value("system.memory_percent.used_memory"),
      sum("vm.monitor.long_message_queue.length", tags: [:process_type]),
      distribution("vm.monitor.long_schedule.timeout",
        tags: [:process_type],
        unit: :millisecond
      ),
      distribution("vm.monitor.long_gc.timeout", tags: [:process_type], unit: :millisecond)
    ] ++
      Electric.Telemetry.Reporters.Prometheus.application_metrics()
  end

  def stack_metrics(stack_id) do
    for_stack = fn metadata -> metadata[:stack_id] == stack_id end

    [
      distribution("electric.plug.serve_shape.duration",
        unit: {:native, :millisecond},
        keep: &(&1[:live] != true && for_stack.(&1))
      ),
      distribution("electric.shape_cache.create_snapshot_task.stop.duration",
        unit: {:native, :millisecond},
        keep: for_stack
      ),
      distribution("electric.storage.make_new_snapshot.stop.duration",
        unit: {:native, :millisecond},
        keep: for_stack
      ),
      distribution("electric.postgres.replication.transaction_received.receive_lag",
        unit: :millisecond,
        keep: for_stack
      ),
      distribution("electric.postgres.replication.transaction_received.operations",
        keep: for_stack
      ),
      distribution("electric.storage.transaction_stored.replication_lag",
        unit: :millisecond,
        keep: for_stack
      )
    ] ++ Electric.Telemetry.Reporters.Prometheus.stack_metrics(stack_id)
  end
end
