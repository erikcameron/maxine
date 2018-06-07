defmodule Maxine.State do
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
