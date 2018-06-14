defmodule Maxine.Data do
  @moduledoc """
  Where we put application data; the only way for 
  callbacks to communicate with the outside world.
  Note that at each event, `:tmp` is wiped and `:options`
  is updated to reflect whatever the current event was
  called with.
  """
  alias Maxine.Machine

  @type sections :: :app | :tmp | :options

  @type t :: %__MODULE__{
    app: %{},
    tmp: %{},
    options: Machine.event_options,
  }

  defstruct app: %{}, tmp: %{}, options: []
end
