defmodule Electric.Telemetry.Opts do
  def schema do
    [
      instance_id: [type: :string, required: true],
      installation_id: [type: :string],
      version: [type: :string, required: true],
      reporters: [
        type: :keyword_list,
        keys: [
          statsd_host: [type: {:or, [:string, nil]}, default: nil],
          call_home_telemetry?: [type: :boolean, default: false],
          otel_metrics?: [type: :boolean, default: false],
          prometheus?: [type: :boolean, default: false],
          otel_export_period: [type: :integer, default: :timer.seconds(30)],
          otel_resource_attributes: [type: :map, default: %{}]
        ]
      ],
      intervals_and_thresholds: [
        type: :keyword_list,
        required: true,
        keys: [
          system_metrics_poll_interval: [type: :integer, default: :timer.seconds(5)],
          top_process_count: [type: :integer, default: 5],
          long_gc_threshold: [type: :integer, default: 500],
          long_schedule_threshold: [type: :integer, default: 500],
          long_message_queue_enable_threshold: [type: :integer, default: 1000],
          long_message_queue_disable_threshold: [type: :integer, default: 100]
        ]
      ]
    ]
  end
end
