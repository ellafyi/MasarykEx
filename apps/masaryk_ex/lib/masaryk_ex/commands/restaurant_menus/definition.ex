defmodule MasarykEx.Commands.RestaurantMenus.Definition do
  @moduledoc "List available restaurant menus."

  use MasarykEx.Core.Command

  alias MasarykEx.Commands.RestaurantMenus.{Restaurants, RestaurantDescriptor}
  alias MasarykEx.Core.{Request, Response, Embed}

  @impl true
  def definition do
    %{
      name: "restaurant-menus",
      description: "List available restaurant menus",
      args: [
        %{
          name: "venue",
          type: :string,
          required: false,
          description: "Which venue to list menus for",
          choices:
            Restaurants.list()
            |> Enum.map(fn r ->
              %{name: r.name, value: r.name}
            end)
        }
      ]
    }
  end

  @impl true
  def config_schema do
    %{enabled: true}
  end

  @impl true
  def run(%Request{args: args}) do
    embeds =
      Restaurants.list()
      |> Enum.filter(fn r ->
        Map.get(args, "venue") == nil || Map.get(args, "venue") == r.name
      end)
      |> Enum.map(fn r -> Task.async(fn -> fetch_one(r) end) end)
      |> Task.await_many(15_000)
      |> Enum.flat_map(fn
        {:ok, embed} -> [embed]
        _ -> []
      end)

    case embeds do
      [] -> Response.text("No menus available today.")
      _ -> %Response{embeds: embeds}
    end
  end

  defp fetch_one(%RestaurantDescriptor.Menicka{id: id} = r) do
    case fetch_menicka(id) do
      {:ok, []} -> :skip
      {:ok, items} -> {:ok, menicka_embed(r, items)}
      _ -> :skip
    end
  end

  defp fetch_one(%RestaurantDescriptor.Wolt{link: link, categories: cats} = r) do
    case fetch_wolt(link, cats) do
      {:ok, {_name, []}} -> :skip
      {:ok, {name, items}} -> {:ok, wolt_embed(r, name, items)}
      _ -> :skip
    end
  end

  defp fetch_one(%RestaurantDescriptor.Func{evaluate: eval} = r) do
    case eval.() do
      {:ok, []} -> :skip
      {:ok, items} -> {:ok, func_embed(r, items)}
      _ -> :skip
    end
  end

  defp menicka_embed(%RestaurantDescriptor.Menicka{name: name, icon: icon, color: color}, items) do
    body =
      items
      |> Enum.reject(&String.match?(&1, ~r/objednat/iu))
      |> Enum.map(&format_menicka_item/1)
      |> Enum.join("\n")

    %Embed{color: color, description: "## #{icon} #{name}\n#{body}"}
  end

  defp format_menicka_item(raw) do
    text = Regex.replace(~r/^\d+[.)]\s*/u, raw, "")

    case Regex.run(~r/^(.*\D)(\d+)\s*Kč\s*$/s, text) do
      [_, dish, price] ->
        clean = dish |> String.replace(~r/\s*\(\d{1,2}(?:,\d{1,2})*\)/u, "") |> String.trim()
        {bold, rest} = split_bold_menicka(clean)
        "• **#{bold}**#{rest}  – *#{price} Kč*"

      _ ->
        text |> String.replace(~r/\s*\(\d{1,2}(?:,\d{1,2})*\)/u, "") |> String.trim()
    end
  end

  defp split_bold_menicka(dish) do
    case String.split(dish, "(", parts: 2) do
      [bold, rest] ->
        {String.trim(bold), " (#{rest}"}

      [bold] ->
        case String.split(bold, ",", parts: 2) do
          [b, r] -> {String.trim(b), ", #{String.trim(r)}"}
          [b] -> {b, ""}
        end
    end
  end

  defp func_embed(%RestaurantDescriptor.Func{name: name, icon: icon, color: color}, items) do
    body =
      Enum.map_join(items, "\n", fn {item_name, price} ->
        case String.split(item_name, ":", parts: 2) do
          [title, desc] -> "• **#{String.trim(title)}**: #{String.trim(desc)}  – *#{price} Kč*"
          [title] -> "• **#{String.trim(title)}**  – *#{price} Kč*"
        end
      end)

    %Embed{color: color, description: "## #{icon} #{name}\n#{body}"}
  end

  defp wolt_embed(%RestaurantDescriptor.Wolt{icon: icon, color: color}, name, items) do
    body =
      Enum.map_join(items, "\n", fn {item_name, price} ->
        {bold, rest} =
          case String.split(item_name, " - ", parts: 2) do
            [n, d] -> {n, " — #{d}"}
            [n] -> {n, ""}
          end

        "• **#{bold}**#{rest}  – *#{price} Kč*"
      end)

    %Embed{color: color, description: "## #{icon} #{name}\n#{body}"}
  end

  defp fetch_wolt(link, categories) do
    slug = URI.parse(link).path |> String.split("/") |> List.last()

    with {:ok, %{status: 200, body: assortment}} <-
           Req.get(
             "https://consumer-api.wolt.com/consumer-api/consumer-assortment/v1/venues/slug/#{slug}/assortment"
           ),
         {:ok, %{status: 200, body: static}} <-
           Req.get(
             "https://consumer-api.wolt.com/order-xp/web/v1/pages/venue/slug/#{slug}/static"
           ) do
      item_ids =
        assortment["categories"]
        |> List.wrap()
        |> Enum.filter(fn cat ->
          cat_slug = cat["slug"] || ""
          categories == [] or Enum.any?(categories, &Regex.match?(&1, cat_slug))
        end)
        |> Enum.flat_map(fn cat -> cat["item_ids"] || [] end)
        |> MapSet.new()

      items =
        assortment["items"]
        |> List.wrap()
        |> Enum.filter(fn item -> MapSet.member?(item_ids, item["id"]) end)
        |> Enum.map(fn item ->
          name = item["name"] || ""
          desc = item["description"] || ""

          label =
            if(desc != "", do: "#{name} - #{desc}", else: name)
            |> String.trim()

          price = round((item["price"] || 0) / 100)
          {label, price}
        end)

      venue_name = get_in(static, ["venue", "name"]) || "Wolt restaurant"
      {:ok, {venue_name, items}}
    else
      {:ok, %{status: status}} -> {:error, "unexpected status: #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_menicka(id) do
    case Req.get("https://www.menicka.cz/#{id}.html") do
      {:ok, %{status: 200, body: body}} ->
        {:ok, document} =
          body |> Codepagex.to_string!(:"VENDORS/MICSFT/WINDOWS/CP1250") |> Floki.parse_document()

        today = Date.utc_today()
        date = "#{today.day}.#{today.month}.#{today.year}"

        items =
          document
          |> Floki.find("div.menicka:has(.nadpis:fl-contains('#{date}')) ul li")
          |> Enum.map(&(&1 |> Floki.text() |> String.trim()))
          |> Enum.reject(&(&1 == ""))

        {:ok, items}

      {:ok, %{status: status}} ->
        {:error, "unexpected status: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
