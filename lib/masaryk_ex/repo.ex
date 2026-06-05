defmodule MasarykEx.Repo do
  @moduledoc "Ecto repository (Postgres). Backs persisted runtime config and feature state."

  use Ecto.Repo,
    otp_app: :masaryk_ex,
    adapter: Ecto.Adapters.Postgres
end
