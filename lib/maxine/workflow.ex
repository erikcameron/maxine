defmodule Maxine.Workflow do
  import Maxine.Ecto
  import Ecto.Changeset
  alias Ecto.Changeset

  @callback machine :: Maxine.Machine.t()

  defmacro __using__ (_options) do
    quote do
      import Ecto.Changeset
      alias Maxine.Machine

      @behaviour Maxine.Workflow 
    end
  end

  @doc """
  Read an event and state from a changeset, and use it to preserve the
  old state and call `cast_state/4`
  """
  def cast_workflow(%Changeset{} = changeset, workflow, options \\ []) do
    event_field = Keyword.get(options, :event_field, :event)
    state_field = Keyword.get(options, :state_field, :state)
    last_state_field = Keyword.get(options, :last_state_field, :last_state)
    last_event_field = Keyword.get(options, :last_state_field, :last_event)

    event = get_field(changeset, event_field)
    current_state = get_field(changeset, state_field)

    last_params = %{
      last_event_field => event, 
      last_state_field => current_state 
    }

    changeset = changeset
                |> cast_state(changeset, event, workflow.machine())
                |> cast(changeset, last_params, Map.keys(last_params))
                |> validate_required([state_field, last_state_field, last_event_field])

    new_state = get_field(changeset, state_field)

    operations = [
      :transform,
      :"transform_leaving_#{old_state}",
      :"transform_on_#{event}",
      :"transform_entering_#{new_state}",
      :validate,
      :"validate_leaving_#{old_state}",
      :"validate_on_#{event}",
      :"validate_entering_#{new_state}"
    ]

    Enum.reduce(operations, changeset, fn operation, changeset ->
      if function_exported?(workflow, operation, 4) do
        apply(workflow, operation, [changeset, event, new_state, last_state])
      else
        changeset
      end
    end
  end
end
