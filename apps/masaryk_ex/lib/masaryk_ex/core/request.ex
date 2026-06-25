defmodule MasarykEx.Core.Request do
  @moduledoc """
  Interface-neutral command invocation, built by an adapter from its native
  input (Discord interaction, CLI argv, …) and handed to the `Dispatcher`.
  """

  alias MasarykEx.Core.Context

  @type t :: %__MODULE__{
          command: String.t(),
          args: %{optional(String.t()) => term()},
          context: Context.t()
        }

  defstruct command: nil, args: %{}, context: %Context{}
end
