defmodule Maxine.Ecto do
  @moduledoc """
  Ecto bindings for Maxine. Provides:
  - `cast_state/4` for updating state on a changeset
  """

  import Maxine
  alias Maxine.State
  alias Maxine.Machine

  @doc """
  Changeset helper that uses the current state of the underlying
  record along with the passed in event to determine what the 
  next state should be, according to the passed in machine. If the
  change is successful, the new state is written to the field. If
  not, an error is added to the changeset.

  ## Options

  * `:field` - the field in which the changeset keeps its state;
  default is `:state`

  Options will be passed to the underlying call to `advance/3` as
  event options.

  Note that it does not look for the relevant state in the params,
  because we assume `cast_state/4` here is the only thing that will
  ever update that field. Plan accordingly.
  """

  @spec cast_state(
    changeset :: %Ecto.Changeset{},
    event :: Machine.event_name,
    machine :: %Machine{},
    options :: Machine.event_options
  ) :: %Ecto.Changeset{}

  def cast_state(changeset, event, machine, options \\ []) do
    field = Keyword.get(options, :field, :state)
    state = Map.get(changeset.data, field, machine.initial) |> state_to_atom

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
  defp state_to_atom(state) when is_atom(state), do: state
  defp state_to_atom(state) when is_binary(state), do: String.to_atom(state)
end
