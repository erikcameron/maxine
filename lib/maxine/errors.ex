defmodule Maxine.Errors do
  defmodule NoSuchEventError do
    @moduledoc """
    On a non-existent event.
    """
    defexception message: "No such event"
  end

  defmodule BadMoveError do
    @moduledoc """
    When the event has no transition mapped for the present
    state.
    """
    defexception message: "bad move"
  end

  defmodule BadCallbackError do
    @moduledoc """
    When a machine requests a non-existent callback function,
    or when a key in the callback index is set to something
    other than a function.
    """
    defexception message: "bad callback"
  end

  defmodule CallbackError do
    @moduledoc """
    For failures in the callback phase. For callbacks 
    themselves, we don't call this one directly. Use
    cause to wrap a more specific error.
    """
    defexception message: "callback failed", cause: nil
  end

  defmodule MachineError do
    @moduledoc """
    For invalid machines only, or bugs in Maxine itself.
    Binds unplanned for results to cause for more info.
    """
    defexception message: "callback failed", cause: nil
  end

  @type error :: 
    %NoSuchEventError{}
    | %BadMoveError{}
    | %BadCallbackError{}
    | %CallbackError{}
    | %MachineError{}
end
