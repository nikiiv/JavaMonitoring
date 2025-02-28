# lib/java_monitor/application.ex
defmodule JavaMonitor.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      # Define your supervision tree
    ]

    opts = [strategy: :one_for_one, name: JavaMonitor.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
