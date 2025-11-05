use Electric.Telemetry

with_telemetry [OtelMetricExporter, Telemetry.Metrics] do
  defmodule Electric.Telemetry.StackTelemetry do
    @moduledoc """
    Collects and exports stack level telemetry such as database and shape metrics.

    If multiple databases are used, each database will have it's own stack and it's own StackTelemetry.

    See also ApplicationTelemetry for application/system level specific telemetry.
    """
    use Supervisor

    alias Electric.Telemetry.Reporters

    require Logger

    @opts_schema NimbleOptions.new!(
                   [stack_id: [type: :string, required: true]] ++ Electric.Telemetry.Opts.schema()
                 )

    def start_link(opts) do
      with {:ok, opts} <- NimbleOptions.validate(opts, @opts_schema) do
        if telemetry_export_enabled?(Map.new(opts)) do
          Supervisor.start_link(__MODULE__, Map.new(opts))
        else
          # Avoid starting the telemetry supervisor and its telemetry_poller child if we're not
          # intending to export periodic measurements metrics anywhere.
          :ignore
        end
      end
    end

    def init(opts) do
      Process.set_label({:stack_telemetry_supervisor, opts.stack_id})
      Logger.metadata(stack_id: opts.stack_id)
      Electric.Telemetry.Sentry.set_tags_context(stack_id: opts.stack_id)

      [telemetry_poller_child_spec(opts) | exporter_child_specs(opts)]
      |> Enum.reject(&is_nil/1)
      |> Supervisor.init(strategy: :one_for_one)
    end

    defp telemetry_poller_child_spec(%{periodic_measurements: []} = _opts), do: nil

    defp telemetry_poller_child_spec(opts) do
      {:telemetry_poller,
       measurements: periodic_measurements(opts),
       period: opts.system_metrics_poll_interval,
       init_delay: :timer.seconds(3)}
    end

    defp telemetry_export_enabled?(opts) do
      exporter_child_specs(opts) != []
    end

    defp exporter_child_specs(opts) do
      [
        Reporters.CallHomeReporter.child_spec(
          opts,
          name: :"stack_call_home_telemetry_#{opts.stack_id}",
          stack_id: opts.stack_id,
          metrics: Reporters.CallHomeReporter.stack_metrics(opts.stack_id)
        ),
        Reporters.Otel.child_spec(opts,
          name: :"stack_otel_telemetry_#{opts.stack_id}",
          metrics: Reporters.Otel.stack_metrics(opts.stack_id)
        ),
        Reporters.Prometheus.child_spec(opts,
          name: :"stack_prometheus_telemetry_#{opts.stack_id}",
          metrics: Reporters.Prometheus.stack_metrics(opts.stack_id)
        ),
        Reporters.Statsd.child_spec(opts, metrics: Reporters.Statsd.stack_metrics(opts.stack_id))
      ]
      |> Enum.reject(&is_nil/1)
    end

    defp periodic_measurements(%{periodic_measurements: funcs} = opts) do
      Enum.map(funcs, fn {m, f, a} when is_atom(m) and is_atom(f) and is_list(a) ->
        {m, f, [opts | a]}
      end)
    end
  end
end
