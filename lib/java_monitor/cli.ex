# lib/java_monitor/cli.ex
defmodule JavaMonitor.CLI do
  @moduledoc """
  CLI interface for standalone usage
  """
  def main(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [interval: :integer, once: :boolean, export: :string],
      aliases: [i: :interval, o: :once, e: :export]
    )

    interval = Keyword.get(opts, :interval, 5000)
    once = Keyword.get(opts, :once, false)
    export_file = Keyword.get(opts, :export)

    # Create ETS table
    :ets.new(:jvm_history, [:named_table, :public, :set])

    if once do
      vms = JavaMonitor.monitor_all_vms()
      JavaMonitor.print_vm_info(vms)

      if export_file do
        JavaMonitor.save_to_json(vms, export_file)
        IO.puts("Data exported to #{export_file}")
      end
    else
      pid = JavaMonitor.start_monitoring(interval)

      # Keep the application running
      Process.monitor(pid)
      receive do
        {:DOWN, _, :process, ^pid, _} -> :ok
      end
    end
  end
end
