defmodule Maxine.Machine do
  alias Maxine.Data

  @moduledoc """
  The actual machine structure
  """
  @type state_name :: atom
  @type event_name :: atom
  @type name :: state_name | event_name
  @type options :: any
  @type callback :: (state_name, state_name, event_name, options -> %Data{})

  @type callback_set :: %{required(name) => callback | [callback]}

  @type transition_index :: %{required(event_name) => %{required(state_name) => state_name}}
  @type callback_index :: %{entering: callback_set, leaving: callback_set, events: callback_set}
  @type alias_index :: %{required(name) => [name]}

  @type t :: %__MODULE__{
    initial: state_name,
    transitions: transition_index,
    callbacks: callback_index,
    aliases: alias_index
  }

  @enforce_keys [:initial, :transitions, :callbacks, :aliases]
  defstruct [:initial, :transitions, :callbacks, :aliases]
end
