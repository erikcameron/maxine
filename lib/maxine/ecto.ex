defmodule Maxine.Ecto do
  @moduledoc """
  Ecto bindings for Maxine. Provides:
  - `cast_state/3` for updating state on a changeset
  """

  import Maxine
  alias Maxine.State
  alias Maxine.Machine
  alias Maxine.Errors.NoSuchStateError
  alias Maxine.Errors.NoSuchEventError

  @doc """
  Changeset helper that uses the current state of the underlying
  record along with the passed in event to determine what the 
  next state should be, according to the passed in machine. If the
  change is successful, the new state is written to the field. If
  not, an error is added to the changeset.

  ## Options

  * `:state` - the field in which the changeset keeps its state;
  default is `:state`
  * `:event` - the field in which the changeset keeps its current event;
  default is `:event`
  * `:validate_with` - A module implementing `validate_state/2` or an equivalent
  function of arity two for validation

  Options will be passed to the underlying call to `advance/3` as
  event options.

  Note that it does not look for the relevant state in the params,
  because we assume `cast_state/4` here is the only thing that will
  ever update that field. Plan accordingly.
  """

  @spec cast_state(
    changeset :: %Ecto.Changeset{},
    machine :: %Machine{},
    options :: Machine.event_options
  ) :: %Ecto.Changeset{}

  def cast_state(changeset, machine, options \\ []) do
    state_field = Keyword.get(options, :state, :state)
    event_field = Keyword.get(options, :event, :event)

    with {:ok, atomized_state} <- atomize_state(changeset, state_field, machine),
         {:ok, atomized_event} <- atomize_event(changeset, event_field),
         %State{} = current <- generate(machine, atomized_state),
         {:ok, next} <- maybe_advance(current, atomized_event, options)
    do
      changeset
      |> Ecto.Changeset.cast(%{state_field => "#{next.name}"}, [state_field])
      |> validate_state(atomized_event, next.name, current.name, options)
    else
      {:error, %NoSuchStateError{} = error} ->
        Ecto.Changeset.add_error(changeset, state_field, "#{error.message}")

      {:error, error} ->
        Ecto.Changeset.add_error(changeset, event_field, "#{error.message}")
    end
  end

  defp maybe_advance(current, nil, _options), do: {:ok, current}
  defp maybe_advance(current, atomized_event, options) do
    advance(current, atomized_event, options)
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

  defp atomize_state(changeset, state_field, machine) do
    string_state = Ecto.Changeset.get_field(changeset, state_field)

    if string_state do
      case maybe_atomize(string_state) do
        :nil -> {:error, %NoSuchStateError{message: "no such state #{string_state}"} }
        atomized_string -> {:ok, atomized_string}
      end
    else
      {:ok, machine.initial}
    end
  end

  defp atomize_event(changeset, event_field) do
    string_event = Ecto.Changeset.get_field(changeset, event_field)

    if string_event do
      case maybe_atomize(string_event) do
        :nil -> {:error, %NoSuchEventError{message: "no such event #{string_event}"} }
        atomized_string -> {:ok, atomized_string}
      end
    else
      {:ok, nil}
    end
  end

  defp maybe_atomize(term) when is_atom(term), do: term
  defp maybe_atomize(term) when is_binary(term) do
    try do
      String.to_existing_atom(term)
    rescue
      ArgumentError -> nil
    end
  end
end
