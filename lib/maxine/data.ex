defmodule Maxine.Data do
  alias Maxine.Machine

  @type t :: %__MODULE__{
    app: %{},
    tmp: %{},
    options: Machine.event_options,
  }

  defstruct app: %{}, tmp: %{}, options: []
end
