defmodule MaxineTest.EctoTest do
  use ExUnit.Case

  import Maxine.Ecto
  alias Maxine.Examples.Package

  defmodule StateInvalidator do
    def validate_state(changeset, _machine_info) do
      Ecto.Changeset.add_error(changeset, :boom, "boom")
    end
  end

  describe "cast_state/4" do
    test "valid on legit state change" do
      changeset = {%{state: "origin"}, %{state: :string}}
        |> Ecto.Changeset.change
        |> cast_state(:ship, Package.machine)

      assert changeset.valid?
    end

    test "uses machine's initial state when changeset state is nil" do
      changeset = {%{state: nil}, %{state: :string}}
        |> Ecto.Changeset.change
        |> cast_state(:automate, Package.machine)

      state = Package.machine
        |> Maxine.generate
        |> Maxine.advance!(:automate)
      
      assert Ecto.Changeset.get_field(changeset, :state) == Atom.to_string(state.name)
    end

    test "invalid on disallowed state change" do
      changeset = {%{state: "origin"}, %{state: :string}}
        |> Ecto.Changeset.change
        |> cast_state(:return, Package.machine)

      assert changeset.errors[:state]
    end   

    test "follows user specified field name" do 
      changeset = {%{foo: "origin"}, %{foo: :string}}
        |> Ecto.Changeset.change
        |> cast_state(:ship, Package.machine, field: :foo)

      assert changeset.valid?
    end   

    test "calls validations when given as a function" do
      invalidator = fn changeset, _machine_info ->
        Ecto.Changeset.add_error(changeset, :boom, "boom")
      end

      changeset = {%{state: "origin"}, %{state: :string}}
        |> Ecto.Changeset.change
        |> cast_state(:ship, Package.machine, validate_with: invalidator)

      assert changeset.errors[:boom]
    end

    test "calls validations when given as a module" do
      changeset = {%{state: "origin"}, %{state: :string}}
        |> Ecto.Changeset.change
        |> cast_state(:ship, Package.machine, validate_with: StateInvalidator)

      assert changeset.errors[:boom]
    end
  end
end
