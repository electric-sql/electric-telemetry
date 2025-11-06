use Electric.Telemetry

with_telemetry [Telemetry.Metrics, OtelMetricExporter] do
  defmodule Electric.Telemetry.ApplicationTelemetry do
    @moduledoc """
    Collects and exports application level telemetry such as CPU, memory and BEAM metrics.

    See also StackTelemetry for stack specific telemetry.
    """
    use Supervisor

    import Telemetry.Metrics

    alias Electric.Telemetry.Reporters

    def start_link(opts) do
      with {:ok, opts} <- Electric.Telemetry.validate_options(opts) do
        if Electric.Telemetry.export_enabled?(opts) do
          Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
        else
          # Avoid starting the telemetry supervisor and its telemetry_poller child if we're not
          # intending to export periodic measurements metrics anywhere.
          :ignore
        end
      end
    end

    def init(opts) do
      children =
        [
          {Electric.Telemetry.SystemMonitor, opts},
          {:telemetry_poller,
           measurements: periodic_measurements(opts),
           period: opts.intervals_and_thresholds.system_metrics_poll_interval,
           init_delay: :timer.seconds(5)}
        ] ++ exporter_child_specs(opts)

      Supervisor.init(children, strategy: :one_for_one)
    end

    defp exporter_child_specs(opts) do
      [
        Reporters.CallHomeReporter.child_spec(
          opts,
          metrics: Reporters.CallHomeReporter.application_metrics()
        ),
        Reporters.Otel.child_spec(opts, metrics: metrics()),
        Reporters.Prometheus.child_spec(opts, metrics: metrics()),
        Reporters.Statsd.child_spec(opts, metrics: statsd_metrics())
      ]
      |> Enum.reject(&is_nil/1)
    end

    def periodic_measurements(%{periodic_measurements: measurements} = telemetry_opts) do
      Enum.flat_map(measurements, fn
        :builtin -> builtin_periodic_measurements(telemetry_opts)
        # These are implemented by telemetry_poller
        f when f in [:memory, :total_run_queue_lengths, :system_counts] -> [f]
        # Bare function names are assumed to be referring to the VMMeasurements module
        f when is_atom(f) -> {Electric.Telemetry.VMMeasurements, f, []}
        {m, f, a} when is_atom(m) and is_atom(f) and is_list(a) -> [{m, f, a}]
      end)
    end

    def periodic_measurements(telemetry_opts), do: builtin_periodic_measurements(telemetry_opts)

    def builtin_periodic_measurements(telemetry_opts) do
      [
        # Measurements included with the telemetry_poller application.
        #
        # By default, The telemetry_poller application starts its own poller but we disable that
        # and add its default measurements to the list of our custom ones.
        #
        # This allows for all periodic measurements to be defined in one place.
        :memory,
        :total_run_queue_lengths,
        :system_counts
      ] ++ Electric.Telemetry.VMMeasurements.periodic_measurements(telemetry_opts)
    end

    def metrics do
      [
        last_value("process.memory.total", tags: [:process_type], unit: :byte),
        last_value("system.cpu.core_count"),
        last_value("system.cpu.utilization.total"),
        last_value("system.load_percent.avg1"),
        last_value("system.load_percent.avg5"),
        last_value("system.load_percent.avg15"),
        last_value("system.memory_percent.free_memory"),
        last_value("system.memory_percent.available_memory"),
        last_value("system.memory_percent.used_memory"),
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
        sum("vm.monitor.long_message_queue.length", tags: [:process_type]),
        distribution("vm.monitor.long_schedule.timeout",
          tags: [:process_type],
          unit: :millisecond
        ),
        distribution("vm.monitor.long_gc.timeout", tags: [:process_type], unit: :millisecond),
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
        cpu_utilization_metrics() ++
        scheduler_utilization_metrics() ++
        run_queue_lengths_metrics()
    end

    def cpu_utilization_metrics do
      1..:erlang.system_info(:logical_processors)
      |> Enum.map(&last_value("system.cpu.utilization.core_#{&1 - 1}"))
    end

    def scheduler_utilization_metrics do
      num_schedulers = :erlang.system_info(:schedulers)
      schedulers_range = 1..num_schedulers

      num_dirty_cpu_schedulers = :erlang.system_info(:dirty_cpu_schedulers)

      dirty_cpu_schedulers_range =
        (num_schedulers + 1)..(num_schedulers + num_dirty_cpu_schedulers)

      Enum.map(schedulers_range, &last_value("vm.scheduler_utilization.normal_#{&1}")) ++
        Enum.map(dirty_cpu_schedulers_range, &last_value("vm.scheduler_utilization.cpu_#{&1}"))
    end

    def run_queue_lengths_metrics do
      Enum.map(Electric.Telemetry.scheduler_ids(), &last_value("vm.run_queue_lengths.#{&1}"))
    end

    def statsd_metrics do
      [
        last_value("vm.memory.total", unit: :byte),
        last_value("vm.memory.processes_used", unit: :byte),
        last_value("vm.memory.binary", unit: :byte),
        last_value("vm.memory.ets", unit: :byte),
        last_value("vm.total_run_queue_lengths.total"),
        last_value("vm.total_run_queue_lengths.cpu"),
        last_value("vm.total_run_queue_lengths.io"),
        last_value("system.load_percent.avg1"),
        last_value("system.load_percent.avg5"),
        last_value("system.load_percent.avg15"),
        last_value("system.memory.free_memory"),
        last_value("system.memory.used_memory"),
        last_value("system.swap.free"),
        last_value("system.swap.used")
      ]
      |> add_instance_id_tag()
    end

    defp add_instance_id_tag(metrics) do
      Enum.map(metrics, fn metric -> Map.update!(metric, :tags, &[:instance_id | &1]) end)
    end
  end
end
