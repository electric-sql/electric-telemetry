use Electric.Telemetry

with_telemetry [Telemetry.Metrics, OtelMetricExporter] do
  defmodule Electric.Telemetry.ApplicationTelemetry do
    @moduledoc """
    Collects and exports application level telemetry such as CPU, memory and BEAM metrics.

    See also StackTelemetry for stack specific telemetry.
    """
    use Supervisor

    alias Electric.Telemetry.Reporters

    require Logger

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
        Reporters.Otel.child_spec(opts,
          metrics: Reporters.Otel.application_metrics()
        ),
        Reporters.Prometheus.child_spec(opts,
          metrics: Reporters.Prometheus.application_metrics()
        ),
        Reporters.Statsd.child_spec(opts, metrics: Reporters.Statsd.application_metrics())
      ]
      |> Enum.reject(&is_nil/1)
    end

    defp periodic_measurements(opts) do
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
      ] ++ Electric.Telemetry.VMMeasurements.periodic_measurements(opts)
    end
  end
end
