defmodule MasarykEx.Core.Event do
  @moduledoc """
  Interface-neutral event handed to services. `type` is a neutral atom (e.g.
  `:message_created`, `:reaction_added`) and `data` is a plain map, so a service
  never touches a Nostrum struct.
  """

  alias MasarykEx.Core.Context

  @type t :: %__MODULE__{
          type: :message_created | :reaction_added | :interval5m | :interval1h | :interval1d,
          data: map(),
          context: Context.t()
        }

  defstruct type: nil, data: %{}, context: %Context{}
end
