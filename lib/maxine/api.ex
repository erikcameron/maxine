defmodule Maxine.API do
  alias Maxine.Machine
  alias Maxine.State
  alias Maxine.Data
  alias Maxine.Errors.MachineFailure

  @moduledoc """
  Functions for dealing with machines
  """

  @doc """
  Creeate a new state machine "instance"
  """
  def generate(%Machine{} = machine, override_initial \\ nil) do
    %State{name: (override_initial || machine.initial), previous: nil, machine: machine, data: %Data{}}
  end

  @doc """
  Where the magic happens. Put in examples later
  """
  def trigger(%State{} = current, event, opts \\ %{}) when is_atom(event) do
    with fresh_state = %State{} <- resolve_next_state(current, event),
      called_back_state = %State{} <- run_callbacks(fresh_state, event, opts)
    do
      clean_state = wipe_tmp_data(called_back_state)
      case next_event(called_back_state) do
        next_event when is_atom(next_event) -> trigger(clean_state, next_event, opts)
        nil -> { :ok, clean_state }
      end
    else
      { :error, error } -> { :error, error }
    end
  end

  def trigger(_, _, _) do
    raise ArgumentError, "trigger requires a state and an event atom-name"
  end

  @doc """
  Exception-raising wrapper (unwrapper?) for the above.
  """
  def trigger!(%State{} = state, event, options \\ %{}) do
    case trigger(state, event, options) do
      { :ok, state = %State{} } -> state
      { :error, error } -> raise error
    end
  end
  
  # Resolve the next state implied by this event, if any.
  # Returns `state` or `{ :error, error }`
  defp resolve_next_state(current, event) do
    with nil <- next_state_for(current.name, current, event),
      nil <- Enum.find_value(aliases_for(current.name, current.machine), fn(x) -> next_state_for(x, current, event) end), 
      nil <- next_state_for(:*, current, event)
    do
      { :error, %MachineFailure{message: "no transitions for event #{event} in state #{current.name}"} }
    else
      state = %State{} -> state 
    end
  end

  # Generate the next machine state struct, or nil
  defp next_state_for(this_state_name, current, event) do
    with event_table when is_map(event_table) <- current.machine.transitions[event],
      next_state_name when is_atom(next_state_name) <- event_table[this_state_name],
      state = %State{} <- generate_next_state(next_state_name, current)
    do
      state 
    else
      nil -> nil
    end
  end

  # Generate a new state struct.
  defp generate_next_state(next_state_name, current) do
    %State{
      name: next_state_name, 
      previous: current.name, 
      data: current.data, 
      machine: current.machine 
    }
  end

  # Fire our various callbacks in an orderly fashion and return
  # an updated state struct or `{ :error, err }`. The new `%State{}`
  # record has already been generated; we just need to fire the 
  # callbacks and merge in the updated `data` field.
  defp run_callbacks(current, event, options) do
    callbacks = build_callbacks_for(current.machine, current.previous, current.name, event)
    new_data  = callback(callbacks, current.previous, current.name, event, current.data, options)
    case new_data do
      %Data{} -> Map.merge(current, %{data: new_data}) 
      { :error, error } -> { :error, error }
    end
  end

  # Build the list of callbacks (literally, a list of functions)
  # possibly specified by the `machine.callbacks` map. 
  defp build_callbacks_for(machine, from, to, event) do
    # Using List.flatten means we can provide either a single
    # callback function per key, or lists thereof; using an empty
    # list as the default element means we don't need to `compact`
    # or some such (Apparently `List.flatten(list)` is meaningfully
    # faster than `Enum.reject(list, &is_nil/1)` too, who knew)
    List.flatten(
      Enum.map(all_names_for(from, machine), &(Map.get(machine[:callbacks][:leaving], &1, []))) ++ 
      Enum.map(all_names_for(to, machine), &(Map.get(machine[:callbacks][:entering], &1, []))) ++
      Enum.map(all_names_for(event, machine), &(Map.get(machine[:callbacks][:events], &1, []))))
  end

  # Given a list of callbacks, run them recursively, allowing each to alter
  # the data field (but nothing else). Callbacks take the form:
  # `cb(from_state, to_state, event, data) -> data`, where the first 
  # three arguments are atoms and the last is a map. 
  defp callback([], _, _, _, data, _), do: data

  defp callback([this_cb | rest], from, to, event, data, options) do
    new_data = this_cb.(from, to, event, data)
    case new_data do
      %{} -> callback(rest, from, to, event, new_data, options)
      { :error, error } -> { :error, error }
    end
  end

  # Determine if any of our callbacks scheduled a next event.
  defp next_event(state) do
    state.data[:tmp][:maxine][:next_event]
  end

  # Get rid of this transition's tmp data
  defp wipe_tmp_data(state) do
    Map.merge(state, %{ tmp: %{} })
  end

  # Generate a list of all handles for this state/event, in
  # decreasing priority
  defp all_names_for(name, machine) do
    List.flatten([name, aliases_for(name, machine), :*])
  end

  # aliases for the name of an event or state
  defp aliases_for(name, machine) do
    Map.get(machine.aliases, name, [])
  end
end
