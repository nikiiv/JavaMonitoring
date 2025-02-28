# lib/java_monitor/jvm_data.ex
defmodule JavaMonitor.JvmData do
  @moduledoc """
  Struct representing Java Virtual Machine monitoring data.
  """
  defstruct [
    # System info
    :hostname,
    :timestamp,
    # VM identity
    :pid,
    :name,
    :app_name,
    :app_variant,
    :main_class,
    # GC metrics
    :old_gen_max,
    :old_gen_current,
    :ygc_count,
    :ygc_time,
    :fgc_count,
    :fgc_time,
    :gc_total_time,
    # Raw data
    :flags
  ]
end
