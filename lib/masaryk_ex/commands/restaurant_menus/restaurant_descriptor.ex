defmodule MasarykEx.Commands.RestaurantMenus.RestaurantDescriptor do
  defmodule Menicka do
    @type t :: %__MODULE__{
      id: integer(),
      name: String.t(),
      icon: String.t(),
      color: integer(),
    }
    defstruct [:id, :name, :icon, :color]
  end

  defmodule Wolt do
    @type t :: %__MODULE__{
      link: String.t(),
      name: String.t() | nil,
      icon: String.t(),
      categories: list(Regex.t()),
      color: integer()
    }
    defstruct [:link, :name, :icon, :categories, :color]
  end

  defmodule Func do
    @type t :: %__MODULE__{
      link: String.t(),
      name: String.t(),
      icon: String.t(),
      color: integer(),
      evaluate: (() -> {:ok, [{String.t(), non_neg_integer()}]} | {:error, term()})
    }
    defstruct [:link, :name, :icon, :color, :evaluate]
  end

  @type t :: Menicka.t() | Wolt.t() | Func.t()
end
