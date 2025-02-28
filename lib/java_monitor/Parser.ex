# lib/parser.ex
defmodule JavaMonitor.Parser do
  @moduledoc """
  Provides parsing functions for Java monitoring data.
  """

  @doc """
  Parses the output of the jps command.
  """
  def parse_jps_line(line) do
    case String.split(line, " ", parts: 2) do
      [pid, name] -> {pid, name}
      [pid] -> {pid, "Unknown"}
    end
  end

  @doc """
  Parses the output of the jinfo command.
  """
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

  @doc """
  Parses the output of the jstat -gc command.
  """
  def parse_jstat_output(output) do
    lines = String.split(output, "\n", trim: true)

    case lines do
      [header, values | _] ->
        headers = String.split(header, ~r/\s+/, trim: true)
        value_list = String.split(values, ~r/\s+/, trim: true)

        # Create a map of header -> value
        data = Enum.zip(headers, value_list) |> Enum.into(%{})

        # Extract specific GC metrics
        %{
          # S0 S1 Eden and Old space
          s0c_space: get_value(data, "S0C"),
          s1c_space: get_value(data, "S1C"),
          oc_space: get_value(data, "OC"),
          ec_space: get_value(data, "EC"),
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
      nil -> 0
      value -> case Float.parse(value) do
        {float_value, _rest} -> float_value |> round()
        :error -> 0.0
      end
    end
  end


  @doc """
  Extracts application information from the parsed jinfo output.
  """
  def extract_app_info(flags) do
    # Extract application name from com.netfolio.appname
    app_name = extract_property(flags, "com.netfolio.appname")

    # Extract variant from com.netfolio.fullname
    variant = extract_property(flags, "com.netfolio.fullname")

    # Extract main class from sun.java.command or similar property
    main_class = extract_main_class(flags)
    max_heap_size =
    extract_property(flags, "-XX:MaxHeapSize")
    |> String.to_integer()
    |> then(fn x -> x / 1024.0 end)
    |> Float.to_string()

    flags = extract_property(flags, "VM Flags")
    IO.inspect(flags, label: "flags")

    %{
      app_name: app_name,
      variant: variant,
      main_class: main_class,
      max_heap_size: max_heap_size
    }
  end

   @doc """
  Parses the output of the jinfo -flags command.
  """
  def parse_flags_output(output) do
    output
    |> String.trim()
    |> String.split("\n")
    |> tl()
    |> List.first()
    |> String.split(" ", trim: true)
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, "=", parts: 2) do
        [key, value] -> Map.put(acc, key, value)
        [key] -> Map.put(acc, key, nil)
      end
    end)
#    |> IO.inspect()
  end



  @doc """
  Prints all keys and values of a map.
  """
  def print_keys_and_values(map) when is_map(map) do
    map
    |> Enum.each(fn {key, value} ->
      IO.puts("#{key}: #{value}")
    end)
  end
  defp extract_property(flags, property_name) do
    flags
    |> Map.keys()
    |> Enum.find_value("unknown", fn key ->
      if String.starts_with?(key, property_name), do: flags[key], else: nil
    end)
  end

  defp extract_main_class(flags) do
    case Map.get(flags, "sun.java.command") do
      nil -> "unknown"
      command -> hd(String.split(command, " "))
    end
  end
end
