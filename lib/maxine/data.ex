defmodule Maxine.Data do
  alias Maxine.Machine

  @type sections :: :app | :tmp | :options

  @type t :: %__MODULE__{
    app: %{},
    tmp: %{},
    options: Machine.event_options,
  }

  defstruct app: %{}, tmp: %{}, options: []
end
