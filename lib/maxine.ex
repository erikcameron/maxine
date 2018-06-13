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

  @moduledoc """
  Functions for dealing with machines.
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

  # Signal types that let us presume any atom is the 
  # name of an event or state; we might normally use
  # nil for that but in Elixir nil is an atom, and 
  # these are explicit. See below for usage.
  defmodule Halt, do: defstruct []
  defmodule Pass, do: defstruct []

  ### Machine API: generate/2, advance/3, advance!/3

  @doc """
  Create a new state machine, optionally specifying a
  starting state other than the one given in the machine.
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
  Where the magic happens. Put in examples later
  """
  @spec advance(
    current :: %State{}, 
    event   :: Machine.event_name, 
    options :: Machine.event_options
  ) :: { :ok, %State{} } | { :error, Maxine.Errors.error }

  def advance(%State{} = current, event, options \\ []) do
    with state = %State{} <- resolve_next_state(current, event, options),
         state = %State{} <- run_callbacks(state, event)
    do
      case next_event(state) do
        %Halt{} -> { :ok, state }
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
  Exception-raising wrapper (unwrapper?) for the above.
  """
  @spec advance!(
    current :: %State{}, 
    event   :: Machine.event_name, 
    options :: Machine.event_options
  ) :: %State{} | no_return

  def advance!(%State{} = current, event, options \\ []) do
    case advance(current, event, options) do
      {:ok, state = %State{} } -> state
      {:error, error }         -> raise error
    end
  end

  ### Callback API: merge_data/3, request/2
  defmodule Callbacks do
    @moduledoc """
    Helper functions for use in callbacks. These get their own module
    because they really don't belong with generate/2 and advance/3.
    The idea is that you
    ```
      import Maxine
    ```
    when you're controlling state machines, and you
    ```
      import Maxine.Callbacks
    ```
    when you're writing callback functions.
    """

    @doc """
    Avoid annoying one-layer "deep merge" issues when sticking 
    things in the %Data{} struct. Sections are (currently) `:app`,
    `:options`, `:tmp`
    """
    @spec merge_data(%Data{}, Data.sections, %{}) :: %Data{}
    def merge_data(%Data{} = data, section, new_data) do
      case Map.get(data, section) do
        sec when is_map(sec) -> Map.merge(data, %{section => Map.merge(sec, new_data)})
        _ -> data
      end
    end

    @doc """
    Tag a %Data{} with an event to fire automatically next.
    Public, for use in callbacks.
    """
    @spec request(
      data    :: %Data{}, 
      event   :: Machine.event_name, 
      options :: Machine.event_options
    ) :: %Data{}

    def request(%Data{} = data, event, options \\ {}) do
      merge_data(data, :tmp, %{_maxine_next_event: event, _maxine_next_options: options})
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
          # The "|| %Pass{}" at the end is for cases where the alias list is empty
          %Pass{} <- Enum.find_value(aliases_for(current.name, current.machine), 
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
  # b/c the state name may be an alias or :*
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
  ) :: [Machine.callback] 

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
  @spec next_event(%State{}) :: Machine.event_options | nil
  defp next_options(%State{} = state) do
    state.data.tmp[:_maxine_next_options]
  end
  ### Utility functions for nmames

  # Generate a list of all handles for this state/event, in
  # decreasing priority
  @spec all_names_for(Machine.name, %Machine{}) :: [Machine.name]
  defp all_names_for(name, machine) do
    List.flatten([name, aliases_for(name, machine), :*])
  end

  # aliases for the name of an event or state
  @spec aliases_for(Machine.name, %Machine{}) :: [Machine.name]
  defp aliases_for(name, machine) do
    Map.get(machine.aliases, name, []) |> List.wrap
  end
end
