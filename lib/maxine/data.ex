defmodule Maxine.Data do
  @type t :: %__MODULE__{
    app: %{},
    maxine: %{},
    tmp: %{}
  }

  defstruct app: %{}, maxine: %{}, tmp: %{}
end
