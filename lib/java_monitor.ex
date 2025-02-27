defmodule JavaMonitor do
  @moduledoc """
  Monitors Java Virtual Machines by collecting information using JDK tools.
  """

  defmodule JvmData do
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
        |> Enum.map(&parse_jps_line/1)
        |> Enum.reject(fn {_pid, name} -> name == "jdk.jcmd/sun.tools.jps.Jps" end)

      {error, _} ->
        IO.puts("Error executing jps: #{error}")
        []
    end
  end

  defp parse_jps_line(line) do
    case String.split(line, " ", parts: 2) do
      [pid, name] -> {pid, name}
      [pid] -> {pid, "Unknown"}
    end
  end

  @doc """
  Gets detailed VM information for a specific PID using jinfo.
  Returns a map with VM details.
  """
  def get_vm_details(pid) do
    flags_result = case System.cmd("jinfo", ["-flags", pid]) do
      {output, 0} ->
        flags = parse_jinfo_output(output)
        app_info = extract_app_info(flags)
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
        parse_jstat_output(output)
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

  defp parse_jstat_output(output) do
    lines = String.split(output, "\n", trim: true)

    case lines do
      [header, values | _] ->
        headers = String.split(header, ~r/\s+/, trim: true)
        value_list = String.split(values, ~r/\s+/, trim: true)

        # Create a map of header -> value
        data = Enum.zip(headers, value_list) |> Enum.into(%{})

        # Extract specific GC metrics
        %{
          # Old generation maximum size (in KB)
          old_gen_max: get_value(data, "OC"),
          # Old generation current size (in KB)
          old_gen_current: get_value(data, "OU"),
          # Young generation GC count
          ygc_count: get_value(data, "YGC"),
          # Young generation GC time (seconds)
          ygc_time: get_value(data, "YGCT"),
          # Full GC count
          fgc_count: get_value(data, "FGC"),
          # Full GC time (seconds)
          fgc_time: get_value(data, "FGCT"),
          # Total GC time (seconds)
          gc_total_time: get_value(data, "GCT")
        }
      _ ->
        %{gc_error: "Invalid jstat output format"}
    end
  end

  defp get_value(data, key) do
    case Map.get(data, key) do
      nil -> "N/A"
      value -> value
    end
  end

  def parse_jinfo_output(output) do
    output
    |> String.trim()
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case Regex.run(~r/([^=\s]+)(?:=([^\s]+))?/, line) do
        [_, key, value] -> Map.put(acc, key, value)
        [_, key] -> Map.put(acc, key, true)
        _ -> acc
      end
    end)
  end

  def extract_app_info(flags) do
    # Extract application name from com.netfolio.appname
    app_name = extract_property(flags, "com.netfolio.appname")

    # Extract variant from com.netfolio.fullname
    variant = extract_property(flags, "com.netfolio.fullname")

    # Extract main class from sun.java.command or similar property
    main_class = extract_main_class(flags)

    %{
      app_name: app_name,
      variant: variant,
      main_class: main_class
    } |> IO.inspect()
  end

  def extract_property(flags, property_name) do
    flags
    |> Map.keys()
    |> Enum.find_value("unknown", fn key ->
      if String.starts_with?(key, property_name), do: flags[key], else: nil
    end)
  end

  def extract_main_class(flags) do
    case Map.get(flags, "sun.java.command") do
      nil -> "unknown"
      command -> hd(String.split(command, " "))
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

# Application supervisor and setup
defmodule JavaMonitor.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Define your supervision tree
    ]

    opts = [strategy: :one_for_one, name: JavaMonitor.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

# CLI interface for standalone usage
defmodule JavaMonitor.CLI do
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
