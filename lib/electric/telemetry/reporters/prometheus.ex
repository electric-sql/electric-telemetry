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

  def application_metrics do
    num_schedulers = :erlang.system_info(:schedulers)
    schedulers_range = 1..num_schedulers

    num_dirty_cpu_schedulers = :erlang.system_info(:dirty_cpu_schedulers)

    dirty_cpu_schedulers_range =
      (num_schedulers + 1)..(num_schedulers + num_dirty_cpu_schedulers)

    [
      last_value("process.memory.total", tags: [:process_type], unit: :byte),
      last_value("system.cpu.core_count"),
      last_value("system.cpu.utilization.total"),
      last_value("vm.garbage_collection.total_runs"),
      last_value("vm.garbage_collection.total_bytes_reclaimed", unit: :byte),
      last_value("vm.memory.atom", unit: :byte),
      last_value("vm.memory.atom_used", unit: :byte),
      last_value("vm.memory.binary", unit: :byte),
      last_value("vm.memory.code", unit: :byte),
      last_value("vm.memory.ets", unit: :byte),
      last_value("vm.memory.processes", unit: :byte),
      last_value("vm.memory.processes_used", unit: :byte),
      last_value("vm.memory.system", unit: :byte),
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.reductions.total"),
      last_value("vm.reductions.delta"),
      last_value("vm.run_queue_lengths.total"),
      last_value("vm.run_queue_lengths.total_plus_io"),
      last_value("vm.scheduler_utilization.total"),
      last_value("vm.scheduler_utilization.weighted"),
      last_value("vm.system_counts.atom_count"),
      last_value("vm.system_counts.port_count"),
      last_value("vm.system_counts.process_count"),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),
      last_value("vm.uptime.total",
        unit: :second,
        measurement: &:erlang.convert_time_unit(&1.total, :native, :second)
      )
    ] ++
      Enum.map(
        # Add "system.cpu.utilization.core_*" but since there's no wildcard support we
        # explicitly add the cores here.
        0..(:erlang.system_info(:logical_processors) - 1),
        &last_value("system.cpu.utilization.core_#{&1}")
      ) ++
      Enum.map(Electric.Telemetry.scheduler_ids(), &last_value("vm.run_queue_lengths.#{&1}")) ++
      Enum.map(schedulers_range, &last_value("vm.scheduler_utilization.normal_#{&1}")) ++
      Enum.map(dirty_cpu_schedulers_range, &last_value("vm.scheduler_utilization.cpu_#{&1}"))
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
