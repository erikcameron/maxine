defmodule Maxine.Workflow do
  @moduledoc """
  A behaviour that specifies a machine and a set of filters to transform and/or
  validate a changeset. The machine is a `%Maxine.Machine{}` and the filters 
  are given in two functions, `events/0` and `states/0` that return maps keyed
  by event name, and whose values are modules implementing the 
  are a module or function to be passed as the `validate_with` option to 
  `cast_state/3`. See `cast_workflow/3` and `cast_state/3` for more
  information. 
  """

  alias Maxine.Machine

  @type machine_tuple :: {:atom, :atom, :atom}
  @type event_name :: :atom
  @type state_name :: :atom
  @type filter_module :: :atom

  @callback machine :: %Machine{}
  @callback events :: %{} | %{ event_name => filter_module }
  @callback states :: %{} | %{ state_name => filter_module }

  defmodule Filter do
    @callback filter(
      changeset :: %Ecto.Changeset{},
      machine_tuple :: Maxine.Workflow.machine_tuple(),
      options :: keyword()
    ) :: %Ecto.Changeset{}
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Maxine.Workflow

      def validate_state(changeset, machine_tuple, options) do
        changeset
        |> filter_event(machine_tuple, options)
        |> filter_state(machine_tuple, options)
      end

      defp filter_event(changeset, machine_tuple, options) do
        {event, _this_state, _prior_state} = machine_tuple
        filter_module = event && Map.get(__MODULE__.events, event)

        if filter_module do
          filter_module.filter(changeset, machine_tuple, options)
        else
          changeset
        end
      end

      defp filter_state(changeset, machine_tuple, options) do
        {_event, this_state, _prior_state} = machine_tuple
        filter_module = Map.get(__MODULE__.states, this_state)

        if filter_module do
          filter_module.filter(changeset, machine_tuple, options)
        else
          changeset
        end
      end
    end
  end

  @doc """
  Uses cast_state/3 to provide a convenient usage pattern.
  """

  @spec cast_workflow(
    changeset :: %Ecto.Changeset{},
    workflow :: :atom
  ) :: %Ecto.Changeset{}

  def cast_workflow(%Ecto.Changeset{} = changeset, workflow, options \\ []) do
    options = Keyword.put(options, :validate_with, workflow)
    Maxine.Ecto.cast_state(changeset, workflow.machine, options)
  end
end
