defmodule Maxine.Errors do
  defmodule NoSuchEventError do
    @moduledoc """
    On a non-existent event.
    """
    defexception message: "No such event"
  end

  defmodule UnavailableEventError do
    @moduledoc """
    When the event has no transition mapped for the present
    state.
    """
    defexception message: "event unavailable"
  end

  defmodule NoSuchCallbackError do
    @moduledoc """
    When a machine requests a non-existent callback function.
    """
    defexception message: "bad callback"
  end

  defmodule CallbackReturnError do
    @moduledoc """
    When a machine returns something other than a %Data{} or
    a %CallbackError.
    """
    defexception message: "bad callback return"
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
    When applying the API to your machine yields unhandleable
    results; back to the drawing board. (It's probably a type
    error of one kind or another.)
    """
    defexception message: "callback failed", cause: nil
  end

  @type error :: 
    %NoSuchEventError{}
    | %UnavailableEventError{}
    | %NoSuchCallbackError{}
    | %CallbackReturnError{}
    | %CallbackError{}
    | %MachineError{}
end
