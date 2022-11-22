defmodule MaxineTest.EctoTest do
  use ExUnit.Case

  import Maxine.Ecto
  alias Maxine.Examples.Package

  defmodule StateInvalidator do
    def validate_state(changeset, _machine_info) do
      Ecto.Changeset.add_error(changeset, :boom, "boom")
    end
  end

  describe "cast_state/3" do
    test "valid on legit state change" do
      changeset = {%{state: "origin", event: "ship"}, %{state: :any, event: :any}}
        |> Ecto.Changeset.change
        |> cast_state(Package.machine)

      assert changeset.valid?
    end

    test "uses machine's initial state when changeset state is nil" do
      changeset = {%{event: :automate}, %{state: :any, event: :any}}
        |> Ecto.Changeset.change
        |> cast_state(Package.machine)

      state = Package.machine
        |> Maxine.generate
        |> Maxine.advance!(:automate)
      
      assert Ecto.Changeset.get_field(changeset, :state) == "#{state.name}"
    end

    test "invalid on disallowed state change" do
      changeset = {%{state: "origin", event: "return"}, %{state: :any, event: :any}}
        |> Ecto.Changeset.change
        |> cast_state(Package.machine)

      assert changeset.errors[:event]
    end   

    test "follows user specified state field name" do 
      changeset = {%{foo: "origin", event: "ship"}, %{foo: :any, event: :any}}
        |> Ecto.Changeset.change
        |> cast_state(Package.machine, state: :foo)

      assert changeset.valid?
    end   

    test "follows user specified event field name" do 
      changeset = {%{state: "origin", foo: "ship"}, %{state: :any, foo: :any}}
        |> Ecto.Changeset.change
        |> cast_state(Package.machine, event: :foo)

      assert changeset.valid?
    end   

    test "calls validations when given as a function" do
      invalidator = fn changeset, _machine_info ->
        Ecto.Changeset.add_error(changeset, :boom, "boom")
      end

      changeset = {%{state: "origin", event: "ship"}, %{state: :any, event: :any}}
        |> Ecto.Changeset.change
        |> cast_state(Package.machine, validate_with: invalidator)

      assert changeset.errors[:boom]
    end

    test "calls validations when given as a module" do
      changeset = {%{state: "origin", event: "ship"}, %{state: :any, event: :any}}
        |> Ecto.Changeset.change
        |> cast_state(Package.machine, validate_with: StateInvalidator)

      assert changeset.errors[:boom]
    end
  end
end
