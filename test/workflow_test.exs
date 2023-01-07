defmodule MaxineTest.WorkflowTest do
  use ExUnit.Case

  import Maxine.Workflow

  alias Maxine.Examples.PackageWorkflow

  describe "cast_workflow/3" do
    test "it advances state and runs filters, events followed by states" do
      attrs = %{name: "package", state: "origin", event: "ship"}
      schema = %{name: :any, state: :any, event: :any}

      changeset = Ecto.Changeset.change({attrs, schema})
                  |> cast_workflow(PackageWorkflow)

      assert Ecto.Changeset.get_field(changeset, :state) == "in_transit"
      assert Ecto.Changeset.get_field(changeset, :name) == "filtered and appended"
      assert changeset.valid?
    end
  end
end
