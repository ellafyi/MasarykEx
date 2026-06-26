defmodule MasarykEx.Commands.Algo.Definition do
  @moduledoc "Say surprise."

  use MasarykEx.Core.Command

  alias MasarykEx.Core.Response

  @impl true
  def definition do
    %{name: "algo", description: "Trick for passing algo", args: []}
  end

  @impl true
  def run(_request) do
    Response.text("https://media.discordapp.net/attachments/504193929839902729/1473246422248722550/IMG_1324.gif?ex=6a403d66&is=6a3eebe6&hm=3ea0fcc986322db699d4fdfa003aedd68255f3347333cb64a33c3591f897b592&=&width=700&height=525")
  end
end
