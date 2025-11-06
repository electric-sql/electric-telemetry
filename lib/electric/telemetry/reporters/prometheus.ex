defmodule Electric.Telemetry.Reporters.Prometheus do
  import Telemetry.Metrics

  def child_spec(telemetry_opts, reporter_opts) do
    if get_in(telemetry_opts, [:reporters, :prometheus?]) do
      reporter_opts
    end
  end

  def start_link(opts) do
    TelemetryMetricsPrometheus.Core.start_link(opts)
  end

  def stack_metrics(stack_id) do
    for_stack = fn metadata -> metadata[:stack_id] == stack_id end

    [
      last_value("electric.postgres.replication.wal_size", unit: :byte, keep: for_stack),
      last_value("electric.storage.used", unit: {:byte, :kilobyte}, keep: for_stack),
      last_value("electric.shapes.total_shapes.count", keep: for_stack),
      last_value("electric.shapes.active_shapes.count", keep: for_stack),
      counter("electric.postgres.replication.transaction_received.count",
        keep: for_stack
      ),
      sum("electric.postgres.replication.transaction_received.bytes",
        unit: :byte,
        keep: for_stack
      ),
      sum("electric.storage.transaction_stored.bytes", unit: :byte, keep: for_stack),
      last_value("electric.shape_monitor.active_reader_count", keep: for_stack),
      last_value("electric.connection.consumers_ready.duration",
        unit: {:native, :millisecond},
        keep: for_stack
      ),
      last_value("electric.connection.consumers_ready.total", keep: for_stack),
      last_value("electric.connection.consumers_ready.failed_to_recover",
        keep: for_stack
      ),
      last_value("electric.admission_control.acquire.current", keep: for_stack),
      sum("electric.admission_control.reject.count", keep: for_stack)
    ]
  end
end
