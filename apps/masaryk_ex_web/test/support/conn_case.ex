defmodule MasarykExWeb.ConnCase do
  @moduledoc """
  Test case for tests that need a connection against `MasarykExWeb.Endpoint`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint MasarykExWeb.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
