defmodule MasarykEx.Core.Response do
  @moduledoc """
  Interface-neutral command result. Each adapter renders it for its medium
  (Discord interaction response, CLI stdout, …). Minimal for now, plain text
  `content`. Richer fields can be added later without touching feature code.
  """

  alias MasarykEx.Core.Embed

  @type t :: %__MODULE__{
          content: String.t(),
          ephemeral: boolean(),
          embed: Embed.t() | nil,
          embeds: [Embed.t()]
        }

  defstruct content: "", ephemeral: false, embed: nil, embeds: []

  @doc "Convenience constructor for a plain text response."
  @spec text(String.t(), keyword()) :: t()
  def text(content, opts \\ []) do
    %__MODULE__{content: content, ephemeral: Keyword.get(opts, :ephemeral, false)}
  end
end
