defmodule Maxine.Signals do
  @moduledoc """
  Sentinel values used by Maxine to signal, repsectively, that no
  further event has been requested, and that no transition for the
  current state was found for a given name of that state, and
  `resolve_next_state` should keep looking under the state's other
  names.  
  """

  defmodule Halt, do: defstruct [] 
  defmodule Pass, do: defstruct []
end
