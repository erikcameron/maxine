defmodule Maxine.Compose do
  @moduledoc """
  Compose individual machines using the optional
  `DeepMerge` dependency.
  """

  alias Maxine.Machine

  @doc """
  Compose two or more individual machines.
  """
  def compose(machines) when is_list(machines) do
    machine = machines
    |> Enum.map(& Map.from_struct(&1))
    |> Enum.reduce(%{}, fn this_machine, comp ->
      DeepMerge.deep_merge(comp, this_machine)
    end)
    
    struct!(Machine, machine)
  end
end
