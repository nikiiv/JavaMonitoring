defmodule JavaMonitorTest do
  use ExUnit.Case
  doctest JavaMonitor

  test "greets the world" do
    assert JavaMonitor.hello() == :world
  end
end
