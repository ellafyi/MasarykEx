defmodule MasarykEx.Services.Starboard.Routing do
  @moduledoc """
  Pure routing for the multi-board starboard: given a guild's boards and the
  membership channel of a reacted message, decide which single board (if any)
  the message belongs to.

  Eligibility: the membership channel must not be in a board's exclude list, and
  must be in its include list (or the include list must be empty = catch-all).
  Most-specific wins: a board that *explicitly* includes the channel beats an
  empty-include catch-all. Ties break by `position`, then `id`. No Repo or
  Discord calls — fully unit-testable.
  """

  alias MasarykEx.Data.Starboard.Starboard

  @doc """
  The single board a message in `membership_channel_id` routes to, or `nil` when
  no board is eligible. Callers pass the boards already scoped to the guild and
  to `enabled`.
  """
  @spec select([Starboard.t()], String.t()) :: Starboard.t() | nil
  def select(boards, membership_channel_id) do
    eligible = Enum.filter(boards, &eligible?(&1, membership_channel_id))

    case Enum.split_with(eligible, &explicit_include?(&1, membership_channel_id)) do
      {[_ | _] = explicit, _catch_all} -> best(explicit)
      {[], catch_all} -> best(catch_all)
    end
  end

  @doc "True when `channel_id` is the target channel of any of the given boards."
  @spec target_channel?([Starboard.t()], String.t()) :: boolean()
  def target_channel?(boards, channel_id) do
    Enum.any?(boards, fn board -> board.target_channel_id == channel_id end)
  end

  defp eligible?(board, mc) do
    mc not in board.exclude_channel_ids and
      (board.include_channel_ids == [] or mc in board.include_channel_ids)
  end

  defp explicit_include?(board, mc), do: mc in board.include_channel_ids

  defp best([]), do: nil
  defp best(boards), do: Enum.min_by(boards, fn board -> {board.position, board.id} end)
end
