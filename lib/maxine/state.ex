defmodule Maxine.State do
  @moduledoc """
  The "state" part of "state machine." These are the structs we
  actually pass around, call events on, and transform in the course
  of normal use. 
  """

  alias Maxine.Machine
  alias Maxine.Data

  @type t :: %__MODULE__{
    name: Machine.state_name, 
    previous: Machine.state_name, 
    machine: %Machine{}, 
    data: %Data{}
  }

  @enforce_keys [:machine, :name, :previous, :data]
  defstruct [:machine, :name, :previous, :data]
end
