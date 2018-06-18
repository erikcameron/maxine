defmodule Maxine do
  alias Maxine.Machine
  alias Maxine.State
  alias Maxine.Data
  alias Maxine.Errors.{ 
    NoSuchEventError,
    UnavailableEventError, 
    NoSuchCallbackError,
    CallbackReturnError, 
    CallbackError, 
    MachineError 
  }
  alias Maxine.Signals.{Halt, Pass}

  @moduledoc """
  Functions for dealing with machines: to wit, `generate/2`, which
  creates an initial `%State{}` struct from a `%Machine{}`, and 
  `advance/3` (along with companion `advance!/3`) which transforms
  one `%State{}` into another one according to the rules given in 
  the machine.
  """

  # Style note: Very long @spec directives are killing my
  # eyes over here. Found not much in the style guide.
  # For anything long enough, using the following, including 
  # a blank line between the spec and the function definition 
  # (but not between the doc and spec):
  #   @doc """
  #   Teh awesomez function
  #   """
  #   @spec function_name(
  #     arg1 :: arg1_type,
  #     arg2 :: arg2_type,
  #     ...
  #     argN :: argN_type
  #   ) :: return_type
  #
  #   def function_name(arg1, arg2, ... argN) do
  #     ...

  ### Machine API: generate/2, advance/3, advance!/3

  @doc """
  Create a new state machine, optionally specifying a
  starting state other than the one given in the machine.

  ## Parameters
    - machine: An instance of `%Machine{}` that specifies events,
      transitions, states, callbacks
    - initial: An optional initial state, overriding the machine's default

  ## Examples
    
      iex> alias Maxine.Examples.Package
      iex> Maxine.generate(Package.machine).name
      :origin

      iex> alias Maxine.Examples.Package
      iex> Maxine.generate(Package.machine, :foobar).name
      :foobar
  """

  @spec generate(
    machine :: %Machine{}, 
    initial :: Machine.state_name
  ) :: %State{}

  def generate(%Machine{} = machine, initial \\ nil) do
    %State{
      name: (initial || machine.initial), 
      previous: nil, 
      machine: machine, 
      data: %Data{}
    }
  end

  @doc """
  Creates a new state record based on the current state, an event,
  and options (optionally). 

  ## Parameters
    - current: A `%State{}` record; the current state
    - event: The name of the event you'd like to call (atom)
    - options: optional arguments to the event; will be preserved
      in state.data.options

  ## Examples

      iex> alias Maxine.Examples.Package
      iex> state = Maxine.generate(Package.machine)
      iex> {:ok, state = %Maxine.State{}} = Maxine.advance(state, :ship)
      iex> state.name
      :in_transit

      iex> alias Maxine.Examples.Package
      iex> state = Maxine.generate(Package.machine)
      iex> {:ok, state = %Maxine.State{}} = Maxine.advance(state, :ship, foo: "bar")
      iex> state.data.options[:foo]
      "bar"
  """
  @spec advance(
    current :: %State{}, 
    event   :: Machine.event_name, 
    options :: Machine.event_options
  ) :: {:ok, %State{}} | {:error, Maxine.Errors.error}

  def advance(%State{} = current, event, options \\ []) do
    with state = %State{} <- resolve_next_state(current, event, options),
         state = %State{} <- run_callbacks(state, event)
    do
      case next_event(state) do
        %Halt{} -> {:ok, state}
        next_event when is_atom(next_event) -> advance(state, next_event, next_options(state))
      end
    else
      err = %NoSuchEventError{}       -> {:error, err} 
      err = %UnavailableEventError{}  -> {:error, err} 
      err = %NoSuchCallbackError{}    -> {:error, err} 
      err = %CallbackReturnError{}    -> {:error, err} 
      err = %CallbackError{}          -> {:error, err}
    end
  rescue
    error -> {:error, %MachineError{message: "advance/3 failed, see cause", cause: error}} 
  end

  @doc """
  Exception-raising wrapper (unwrapper?) for the `advance/3`.

  ## Parameters
    - current: A `%State{}` record; the current state
    - event: The name of the event you'd like to call (atom)
    - options: optional arguments to the event; will be preserved

  ## Examples
    
      iex> alias Maxine.Examples.Package
      iex> state = Maxine.generate(Package.machine)
      iex> state = Maxine.advance!(state, :ship)
      iex> state.name
      :in_transit 

  """

  @spec advance!(
    current :: %State{}, 
    event   :: Machine.event_name, 
    options :: Machine.event_options
  ) :: %State{} | no_return

  def advance!(%State{} = current, event, options \\ []) do
    case advance(current, event, options) do
      {:ok, state = %State{}} -> state
      {:error, error}         -> raise error
    end
  end

  ### State resolution
  
  # Resolve the next state implied by this event, if any.
  # Returns `state` or `{ :error, error }`
  @spec resolve_next_state(
    current :: %State{}, 
    event   :: Machine.event_name, 
    options :: Machine.event_options
  ) :: %State{} | %UnavailableEventError{} | %NoSuchEventError{}

  defp resolve_next_state(current, event, options) do
    with  %Pass{} <- next_state_for(current.name, current, event, options),
          # The "|| %Pass{}" at the end is for cases where the group list is empty
          %Pass{} <- Enum.find_value(groups_for(current.name, current.machine), 
                            fn(x) -> next_state_for(x, current, event, options) end) || %Pass{},
          %Pass{} <- next_state_for(:*, current, event, options)
    do
      %UnavailableEventError{message: "Event #{event} not available in state #{current.name}"}
    else
      state = %State{}                  -> state 
      error = %UnavailableEventError{}  -> error
      error = %NoSuchEventError{}       -> error
    end
  end

  # Generate the next machine state struct, or nil. Note that
  # we're explicitly passing the name in as the first argument,
  # rather than deriving it from the current state---this is 
  # b/c the state name may be an group name or :*
  @spec next_state_for(
    this_state_name :: Machine.state_name, 
    current         :: %State{}, 
    event           :: Machine.event_name, 
    options         :: Machine.event_options
  ) :: %State{} | %NoSuchEventError{} | %Pass{}

  defp next_state_for(this_state_name, current, event, options) do
    with event_table when is_map(event_table) <- 
        # Before you ask: Wrapping the error in a list here because
        # exceptions are just maps, and our logic is set to look
        # for maps for the event table. #hackish
        Map.get(current.machine.transitions, event,  List.wrap(%NoSuchEventError{message: event})),
      next_state_name when not is_nil(next_state_name) <- 
        Map.get(event_table, this_state_name),
      state = %State{} <- 
        generate_next_state(next_state_name, current, options)
    do
      state 
    else
      [error = %NoSuchEventError{}] -> error
      nil -> %Pass{}
    end
  end

  # From an existing machine state, generate the next one.
  @spec generate_next_state(
    next_state_name :: Machine.state_name, 
    current         :: %State{}, 
    options         :: Machine.event_options
  ) :: %State{}

  defp generate_next_state(next_state_name, current, options) do
    %State{
      name: next_state_name, 
      previous: current.name, 
      data: Map.merge(current.data, %{options: options, tmp: %{}}), 
      machine: current.machine 
    }
  end
  
  ### Callbacks

  # Fire our various callbacks in an orderly fashion and return
  # an updated state struct or `{ :error, err }`. The new `%State{}`
  # record has already been generated; we just need to fire the 
  # callbacks and merge in the updated `data` field.
  @spec run_callbacks(
    current :: %State{}, 
    event   :: Machine.event_name
  ) :: %Data{} | %CallbackError{} 

  defp run_callbacks(current, event) do
    cb_list = build_callbacks(current.machine, current.previous, current.name, event)
    case call_callbacks(cb_list, current.previous, current.name, event, current.data) do
      data  = %Data{}                 -> Map.merge(current, %{data: data}) 
      error = %NoSuchCallbackError{}  -> error 
      error = %CallbackReturnError{}  -> error 
      error = %CallbackError{}        -> error 
    end
  end

  # Build the list of callbacks (literally, a list of functions)
  # possibly specified by the `machine.callbacks` map. 
  @spec build_callbacks(
    machine :: %Machine{}, 
    from    :: Machine.state_name, 
    to      :: Machine.state_name, 
    event   :: Machine.event_name
  ) :: [Machine.callback | %NoSuchCallbackError{}] 

  defp build_callbacks(machine, from, to, event) do
    # Using List.flatten means we can provide either a single
    # callback function per key, or lists thereof; using an empty
    # list as the default element means we don't need to `compact`
    # or some such (Apparently `List.flatten(list)` is meaningfully
    # faster than `Enum.reject(list, &is_nil/1)` too, who knew)
    Enum.map(all_names_for(from, machine), fn(name) -> Map.get(machine.callbacks[:leaving], name, []) end) ++ 
      Enum.map(all_names_for(to, machine), fn(name) -> Map.get(machine.callbacks[:entering], name, []) end) ++ 
      Enum.map(all_names_for(event, machine), fn(name) -> Map.get(machine.callbacks[:events], name, []) end) 
    |> List.flatten
    |> Enum.map(fn(cb) -> machine.callbacks.index[cb] || %NoSuchCallbackError{message: cb} end)
  end

  # Given a list of callbacks, run them recursively, allowing each to inject a
  # new data record into the process (but nothing else). Callbacks (see `Machine.callback`)
  # take names of the from state, to state and event, along with the %Data{},
  # and return either a new %Data{} or a %CallbackError{}, which will halt
  # the chain and cause `advance/3` to fail. Additionally, a missing function
  # from the index will resolve in the function above to a %CallbackError{}
  # in the function list, which we will return here. (Easier/more elegant
  # than trying to get an error out of the mapped function above, which 
  # would probably require raising)
  @spec call_callbacks(
    my_callbacks  :: [Machine.callback], 
    from          :: Machine.state_name, 
    to            :: Machine.state_name, 
    event         :: Machine.event_name, 
    data          :: %Data{}
  ) :: %Data{} | %CallbackError{} | %CallbackReturnError{} | %NoSuchCallbackError{}

  defp call_callbacks([this_cb | rest], from, to, event, data) do
    case this_cb do 
      this_cb when is_function(this_cb) -> 
        case this_cb.(from, to, event, data) do
          new_data = %Data{}          -> call_callbacks(rest, from, to, event, new_data)
          error    = %CallbackError{} -> error
          _ -> %CallbackReturnError{message: "Illegal return (event #{event}, from #{from}, to #{to}"}
        end
      error = %NoSuchCallbackError{} -> error
    end
  end
  defp call_callbacks([], _, _, _, data), do: data

  ### Triggering events
  # Determine if any of our callbacks scheduled a next event.
  @spec next_event(%State{}) :: Machine.event_name | %Halt{}
  defp next_event(%State{} = state) do
    state.data.tmp[:_maxine_next_event] || %Halt{}
  end
  
  # Extract any options the callbacks left for the next event.
  @spec next_options(%State{}) :: Machine.event_options | nil
  defp next_options(%State{} = state) do
    state.data.tmp[:_maxine_next_options]
  end
  ### Utility functions for nmames

  # Generate a list of all handles for this state/event, in
  # decreasing priority
  @spec all_names_for(Machine.name, %Machine{}) :: [Machine.name]
  defp all_names_for(name, machine) do
    List.flatten([name, groups_for(name, machine), :*])
  end

  # groups for for the name of an event or state
  @spec groups_for(Machine.name, %Machine{}) :: [Machine.name]
  defp groups_for(name, machine) do
    Map.get(machine.groups, name, []) |> List.wrap
  end
end
