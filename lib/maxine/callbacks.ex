defmodule Maxine.Callbacks do
  alias Maxine.{Data, Machine}

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
  things in `%Data{}` structs.

  ## Parameters
    - data: The `%Data{}` struct we're merging into
    - section: The slice of `data` we're using; can be `:app`, `:options` or `:tmp`
    - to_merge: A map holding the data we want to merge

  ## Examples
  
    iex> new_data = Maxine.Callbacks.merge_data(%Maxine.Data{}, :app, %{hello: "world"})
    iex> new_data.app[:hello]
    "world"

  """
  @spec merge_data(%Data{}, Data.sections, map) :: %Data{}
  def merge_data(%Data{} = data, section, to_merge) do
    case Map.get(data, section) do
      sec when is_map(sec) -> Map.merge(data, %{section => Map.merge(sec, to_merge)})
      _ -> data
    end
  end

  @doc """
  Tag a `%Data{}` with an event to fire automatically next. (Note
  here: Checking the key on the tmp map directly as we do in the
  examples below is not how you want to use it, and means
  implementation is leaking into the doctests, which isn't ideal,
  but the corresponding function to read this stuff is private
  in `Maxine` so it's frankly easier and more transparent here
  to just roll with it, as long as we're all clear that you
  should probably not do things like this in production/real life.)

  ## Parameters
    - data: the `%Data{}` struct we're tagging - event: the event
    we'd like fired when this callback cycle is done (atom) -
    options: Optional, any thing we'd like to go along with the
    event

  ## Examples
  
    iex> new_data = Maxine.Callbacks.request(%Maxine.Data{}, :ship, foo: "bar")
    iex> new_data.tmp[:_maxine_next_event]
    :ship

    iex> new_data = Maxine.Callbacks.request(%Maxine.Data{}, :ship, foo: "bar")
    iex> new_data.tmp[:_maxine_next_options][:foo]
    "bar"

  """
  @spec request(
    data    :: %Data{}, 
    event   :: Machine.event_name, 
    options :: Machine.event_options
  ) :: %Data{}

  def request(%Data{} = data, event, options \\ []) do
    merge_data(data, :tmp, %{_maxine_next_event: event, _maxine_next_options: options})
  end
end
