defmodule MasarykEx.Core.Context do
  @moduledoc """
  Interface-neutral description of who triggered something and where. Adapters
  fill this in so the core can resolve per-guild config without knowing which
  interface it is talking to.
  """

  @type interface :: :discord | :cli | :web

  # TODO REFACTOR Really user_id and guild_id and channel_id should be ints, not strings
  @type t :: %__MODULE__{
          interface: interface(),
          user_id: String.t() | nil,
          guild_id: String.t() | nil,
          channel_id: String.t() | nil
        }

  defstruct interface: nil, user_id: nil, guild_id: nil, channel_id: nil
end
