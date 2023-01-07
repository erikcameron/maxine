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

  defmodule Filter do
    @callback filter(
      changeset :: %Ecto.Changeset{}, 
      options :: keyword()
    ) :: %Ecto.Changeset{}
  end

  alias Maxine.Machine

  @type event_name :: :atom
  @type state_name :: :atom
  @type filter_module :: :atom

  @callback machine :: %Machine{}
  @callback events :: %{} | %{ event_name => filter_module }
  @callback states :: %{} | %{ state_name => filter_module }

  defmacro __using__(_opts) do
    quote do
      @behaviour Maxine.Workflow

      def validate_state(changeset, {event, next, _current}, options) do
        changeset
        |> filter_event(event, options)
        |> filter_state(next, options)
      end

      defp filter_event(changeset, event, options) do
        filter_module = event && Map.get(__MODULE__.events, event)

        if filter_module do
          filter_module.filter(changeset, options)
        else
          changeset
        end
      end

      defp filter_state(changeset, state, options) do
        filter_module = Map.get(__MODULE__.states, state)

        if filter_module do
          filter_module.filter(changeset, options)
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
