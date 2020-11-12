defmodule Maxine.Compose do
  @moduledoc """
  Compose individual machines using the optional
  `DeepMerge` dependency.
  """

  alias Maxine.Machine

  @doc """
  Compose machines.
  """
  def compose(%Machine{} = machine), do: machine
  def compose([%Machine{} = machine]), do: machine
  def compose(machines) when is_list(machines) do
    machine = machines
    |> Enum.map(& unwrap_machine_struct!(&1))
    |> Enum.reduce(%{}, fn this_machine, comp ->
      DeepMerge.deep_merge(comp, this_machine)
    end)
    
    struct!(Machine, machine)
  end
  def compose(_), do: raise ArgumentError, "can only compose machines"

  defp unwrap_machine_struct!(machine) do
    case machine do
      %Machine{} -> Map.from_struct(machine)
      _ -> 
        raise ArgumentError, "can only compose machines, got: #{IO.inspect(machine)}"
    end
  end
end
