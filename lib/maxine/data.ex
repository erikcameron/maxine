defmodule Maxine.Data do
  @type sections :: :app | :options | :tmp
  @type section :: %{}
  @type t :: %__MODULE__{
    app: section,
    options: section,
    tmp: section
  }

  defstruct app: %{}, options: %{}, tmp: %{}
end
