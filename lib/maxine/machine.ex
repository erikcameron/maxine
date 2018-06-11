defmodule Maxine.Machine do
  alias Maxine.Data

  @moduledoc """
  The actual machine structure
  """
  @type state_name :: atom
  @type event_name :: atom
  @type cb_name :: atom
  @type name :: state_name | event_name | cb_name

  @type event_options :: []
  @type callback :: (from :: state_name, to :: state_name, event_name, event_options -> %Data{})
  @type cb_listing :: %{required(name) => cb_name | [cb_name]}
  @type cb_index :: %{required(cb_name) => callback}

  @type transition_map :: %{required(event_name) => %{required(state_name) => state_name}}
  @type callback_map :: %{entering: cb_listing, leaving: cb_listing, events: cb_listing, index: cb_index}
  @type alias_map :: %{required(name) => [name]}

  @type t :: %__MODULE__{
    initial: state_name,
    transitions: transition_map,
    callbacks: callback_map,
    aliases: alias_map
  }

  @enforce_keys [:initial, :transitions, :callbacks, :aliases]
  defstruct [:initial, :transitions, :callbacks, :aliases]
end
