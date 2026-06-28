defmodule MasarykEx.Commands.RestaurantMenus.Restaurants do
  alias MasarykEx.Commands.RestaurantMenus.RestaurantDescriptor

  def list do
    [
      %RestaurantDescriptor.Menicka{id: 4116, name: "Padagali", icon: "🍽", color: 0xF15850},
      %RestaurantDescriptor.Menicka{
        id: 2752,
        name: "U Dřeváka Beer&Grill",
        icon: "🍔",
        color: 0x7C1C14
      },
      %RestaurantDescriptor.Menicka{id: 6695, name: "U Karla", icon: "🍗", color: 0xFFFFFF},
      %RestaurantDescriptor.Wolt{
        link: "https://wolt.com/en/cze/brno/restaurant/bistro-bastardo-stefanikova",
        name: "Bistro Bastardo",
        icon: "🥙",
        categories: [~r/tydenni-menu/],
        color: 0xE8B84B
      },

      # Bistro Bastardo
      %RestaurantDescriptor.Func{
        link: "https://www.taorestaurant.cz/tydenni_menu/nabidka/",
        name: "Táo Viet Nam",
        icon: "🍜",
        color: 0x66AD2D,
        evaluate: fn ->
          emoji =
            ~r/[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{1F1E6}-\x{1F1FF}\x{2B00}-\x{2BFF}\x{FE0F}\x{200D}]/u

          code = ~r/^\s*(?:\d+\.\s*)?(?:M\d+\s*[:,]\s*)?/iu
          price_re = ~r/(\d+)\s*[Kk][Ččc]\.?/u
          dots = ~r/[.…]+/u

          weekday =
            case Date.day_of_week(Date.utc_today()) do
              1 -> "pondělí"
              2 -> "úterý"
              3 -> "středa"
              4 -> "čtvrtek"
              5 -> "pátek"
              _ -> nil
            end

          keep? = fn text ->
            String.length(text) > 20 and
              (String.match?(text, ~r/^\d/) or
                 (weekday != nil and String.contains?(String.downcase(text), weekday)))
          end

          parse = fn raw ->
            text =
              raw
              |> String.replace(emoji, "")
              |> String.normalize(:nfc)
              |> String.replace(code, "")
              |> String.trim()

            case Regex.run(price_re, text) do
              [match, price] ->
                name =
                  text
                  |> String.replace(match, "", global: false)
                  |> String.replace(~r/\s*[-–—]\s*$/u, "")
                  |> String.replace(~r/\d{1,2}(?:,\d{1,2})+/u, "")
                  |> String.replace(dots, "")
                  |> String.replace(~r/[ \t]+/u, " ")
                  |> String.trim()

                {:ok, {name, String.to_integer(price)}}

              _ ->
                :error
            end
          end

          case Req.get("https://www.taorestaurant.cz/tydenni_menu/nabidka/") do
            {:ok, %{status: 200, body: body}} ->
              {:ok, document} = Floki.parse_document(body)

              items =
                document
                |> Floki.find(".tydenni-menu-text")
                |> Enum.map(fn block -> block |> Floki.text() |> String.trim() end)
                |> Enum.filter(keep?)
                |> Enum.flat_map(fn raw ->
                  case parse.(raw) do
                    {:ok, item} -> [item]
                    :error -> []
                  end
                end)

              {:ok, items}

            {:ok, %{status: status}} ->
              {:error, "unexpected status:  #{status}"}

            {:error, reason} ->
              {:error, reason}
          end
        end
      }
    ]
  end
end
