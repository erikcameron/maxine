defmodule Maxine.Ecto do
  @moduledoc """
  Ecto bindings for Maxine. Provides:
  - `cast_state/4` for updating state on a changeset
  """

  import Maxine
  alias Maxine.State

  def cast_state(changeset, event, machine, options \\ []) do
    field = Keyword.get(options, :field, :state)
    state = Map.get(changeset.data, field) |> state_to_atom

    with %State{} = current <- generate(machine, state),
      {:ok, next} <- advance(current, event, options)
    do
      Ecto.Changeset.cast(changeset, %{field => "#{next.name}"}, [field])
    else
      {:error, error} -> 
        Ecto.Changeset.add_error(changeset, field, error.message)
    end
  end

  defp state_to_atom(nil), do: raise ArgumentError, "missing state"
  defp state_to_atom(state) when is_binary(state), do: String.to_atom(state)
end
