# lib/java_monitor.ex
defmodule JavaMonitor do
  @moduledoc """
  Monitors Java Virtual Machines by collecting information using JDK tools.
  """

  alias JavaMonitor.JvmData
  alias JavaMonitor.Parser

  @spec list_java_vms() :: list()
  @doc """
  Lists all running Java VMs using jps command.
  Returns a list of {pid, name} tuples.
  """
  def list_java_vms do
    case System.cmd("jps", ["-l"]) do
      {output, 0} ->
        output
        |> String.trim()
        |> String.split("\n")
        |> Enum.map(&Parser.parse_jps_line/1)
        |> Enum.reject(fn {_pid, name} -> name == "jdk.jcmd/sun.tools.jps.Jps" end)

      {error, _} ->
        IO.puts("Error executing jps: #{error}")
        []
    end
  end

  @doc """
  Gets detailed VM information for a specific PID using jinfo.
  Returns a map with VM details.
  """
  def get_vm_details(pid) do
    flags_result = case System.cmd("jinfo", ["-sysprops",pid]) do
      {output, 0} ->
        flags = Parser.parse_jinfo_output(output)
        flags
        |> Enum.each(fn {key, value} ->
          IO.puts("PAIR:  #{key}: #{value}")

        end)


        app_info = Parser.extract_app_info(flags)
        IO.inspect(app_info, label: "App Info")
        %{
          pid: pid,
          flags: flags,
          app_name: app_info.app_name,
          app_variant: app_info.variant,
          main_class: app_info.main_class
        }

      {error, _} ->
        IO.puts("Error executing jinfo for PID #{pid}: #{error}")
        %{pid: pid, error: "Failed to get VM details"}
    end

    # Add GC information
    gc_info = get_gc_info(pid)
    Map.merge(flags_result, gc_info)
  end

  @doc """
  Gets garbage collection information for a specific PID using jstat.
  """
  def get_gc_info(pid) do
    case System.cmd("jstat", ["-gc", pid]) do
      {output, 0} ->
        Parser.parse_jstat_output(output)
      {error, _} ->
        IO.puts("Error executing jstat for PID #{pid}: #{error}")
        %{
          old_gen_max: "N/A",
          old_gen_current: "N/A",
          ygc_count: "0",
          ygc_time: "0",
          fgc_count: "0",
          fgc_time: "0",
          gc_total_time: "0"
        }
    end
  end


  @doc """
  Saves the current monitoring data to a JSON file.
  """
  def save_to_json(vms, filename \\ "java_monitor_data.json") do
    # Convert structs to maps for JSON encoding
    json_data = Enum.map(vms, fn vm ->
      vm
      |> Map.from_struct()
      |> Map.update!(:timestamp, &DateTime.to_iso8601/1)
    end)

    case Jason.encode(json_data, pretty: true) do
      {:ok, json} ->
        File.write(filename, json)
      {:error, reason} ->
        IO.puts("Error encoding JSON: #{inspect(reason)}")
        {:error, reason}
    end
  end


  @doc """
  Monitors all Java VMs and returns their details as JvmData structs.
  """
  def monitor_all_vms do
    hostname = get_hostname()
    timestamp = DateTime.utc_now()

    list_java_vms()
    |> Enum.map(fn {pid, name} ->
      details = get_vm_details(pid)

      # Convert map to struct
      %JvmData{
        # System info
        hostname: hostname,
        timestamp: timestamp,
        # VM identity
        pid: pid,
        name: name,
        app_name: details[:app_name],
        app_variant: details[:app_variant],
        main_class: details[:main_class],
        # GC metrics
        old_gen_max: details[:old_gen_max],
        old_gen_current: details[:old_gen_current],
        ygc_count: details[:ygc_count],
        ygc_time: details[:ygc_time],
        fgc_count: details[:fgc_count],
        fgc_time: details[:fgc_time],
        gc_total_time: details[:gc_total_time],
        # Raw data
        flags: details[:flags]
      }
    end)
  end

  @doc """
  Gets the current system hostname.
  """
  def get_hostname do
    case System.cmd("hostname", []) do
      {hostname, 0} -> String.trim(hostname)
      _ -> "unknown"
    end
  end

  @doc """
  Starts monitoring Java VMs at regular intervals.
  Returns monitoring process PID.
  """
  def start_monitoring(interval_ms \\ 5000) do
    # Store data in an ETS table for potential future use
    :ets.new(:jvm_history, [:named_table, :public, :set])

    spawn_link(fn -> monitoring_loop(interval_ms) end)
  end

  @doc """
  Stores monitoring data in ETS table and manages data retention.
  """
  def monitoring_loop(interval_ms) do
    vms = monitor_all_vms()
    print_vm_info(vms)

    # Store data in ETS table with timestamp as key
    now = :os.system_time(:millisecond)
    :ets.insert(:jvm_history, {now, vms})

    # Cleanup old entries (keep last 100 snapshots)
    cleanup_old_data(100)

    :timer.sleep(interval_ms)
    monitoring_loop(interval_ms)
  end

  @doc """
  Cleans up old data entries, keeping only the most recent ones.
  """
  def cleanup_old_data(keep_count) do
    # Get all keys and sort them
    keys = :ets.select(:jvm_history, [{{:"$1", :_}, [], [:"$1"]}])
    |> Enum.sort(:desc)

    # Delete older entries beyond the keep count
    if length(keys) > keep_count do
      keys
      |> Enum.drop(keep_count)
      |> Enum.each(fn key -> :ets.delete(:jvm_history, key) end)
    end
  end

  @doc """
  Prints VM information to console in a readable format.
  """
  def print_vm_info(vms) do
    # Get the first VM's system info (all VMs will have the same hostname and timestamp)
    system_info = case vms do
      [first | _] -> %{hostname: first.hostname, timestamp: first.timestamp}
      _ -> %{hostname: "unknown", timestamp: DateTime.utc_now()}
    end

    IO.puts("\n#{String.duplicate("=", 80)}")
    IO.puts("Java VM Monitor - Host: #{system_info.hostname}, Time: #{system_info.timestamp}")
    IO.puts(String.duplicate("=", 80))

    Enum.each(vms, fn vm ->
      IO.puts("PID: #{vm.pid}")
      IO.puts("Name: #{vm.name}")
      IO.puts("App Name: #{vm.app_name}")
      IO.puts("App Variant: #{vm.app_variant}")
      IO.puts("Main Class: #{vm.main_class}")

      # Print GC information
      IO.puts("\nGarbage Collection Stats:")
      IO.puts("  Old Gen Size: #{vm.old_gen_current} KB / #{vm.old_gen_max} KB")
      IO.puts("  Young GC: #{vm.ygc_count} collections, #{vm.ygc_time}s total")
      IO.puts("  Full GC: #{vm.fgc_count} collections, #{vm.fgc_time}s total")
      IO.puts("  Total GC Time: #{vm.gc_total_time}s")

      IO.puts(String.duplicate("-", 40))
    end)
  end
end
