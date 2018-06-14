defmodule Maxine.Signals do
  @moduledoc """
  Sentinel values used by Maxine to signal that no
  further event has been requested, (`Halt`) and that no transition for the
  current state was found for a given name of that state, and
  `resolve_next_state` should keep looking under the state's other
  names (`Pass`).  
  """

  defmodule Halt, do: defstruct [] 
  defmodule Pass, do: defstruct []
end
