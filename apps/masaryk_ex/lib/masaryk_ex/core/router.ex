defmodule MasarykEx.Core.Router do
  @moduledoc """
  Fans a neutral `%Event{}` out to every enabled passive service, each in a
  fire-and-forget Task with its resolved config map.
  """

  alias MasarykEx.Autoloader
  alias MasarykEx.Core.Event

  require Logger

  @spec dispatch(Event.t()) :: :ok
  def dispatch(%Event{context: context} = event) do
    Autoloader.modules_with_function(MasarykEx.Services, :handle_event, 2)
    |> Enum.each(fn module ->
      if MasarykEx.Config.get(module, :enabled, context) do
        Task.start(fn ->
          try do
            module.handle_event(event, MasarykEx.Config.all(module, context))
          rescue
            err -> Logger.error("Service #{inspect(module)} crashed: #{Exception.message(err)}")
          end
        end)
      end
    end)

    :ok
  end
end
