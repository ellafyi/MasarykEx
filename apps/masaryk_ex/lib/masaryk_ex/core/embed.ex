defmodule MasarykEx.Core.Embed do
  @moduledoc """
  Interface-neutral rich message. The Discord adapter renders it as a real embed and
  the CLI renders it as text. Fields are `%{name, value, inline}` maps.
  """

  @type field :: %{
          required(:name) => String.t(),
          required(:value) => String.t(),
          optional(:inline) => boolean()
        }

  @type t :: %__MODULE__{
          title: String.t() | nil,
          description: String.t() | nil,
          color: non_neg_integer() | nil,
          footer: String.t() | nil,
          fields: [field()]
        }

  defstruct title: nil, description: nil, color: nil, footer: nil, fields: []
end
