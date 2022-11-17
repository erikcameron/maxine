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
    state = (Ecto.Changeset.get_field(changeset, field) || machine.initial) |> state_to_atom

    with %State{} = current <- generate(machine, state),
      {:ok, next} <- advance(current, event, options)
    do
      changeset
      |> Ecto.Changeset.cast(%{field => "#{next.name}"}, [field])
      |> validate_state(event, next.name, current.name, options)
    else
      {:error, error} -> 
        Ecto.Changeset.add_error(changeset, field, "#{error.message}")
    end
  end

  defp validate_state(changeset, event, next, current, options) do
    validator_tuple = {event, next, current}

    case Keyword.get(options, :validate_with) do
      nil -> changeset
      validator when is_function(validator, 2) ->
        validator.(changeset, validator_tuple)
      validator when is_atom(validator) ->
        if function_exported?(validator, :validate_state, 2) do
          apply(validator, :validate_state, [changeset, validator_tuple])
        else
          changeset
        end
      _ -> raise ArgumentError,
        "validator must be a function or a module with validate_state/2"
    end
  end

  defp state_to_atom(nil), do: raise ArgumentError, "missing state"
  defp state_to_atom(state) when is_atom(state), do: state
  defp state_to_atom(state) when is_binary(state), do: String.to_atom(state)
end
