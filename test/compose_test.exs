defmodule Maxine.ComposeTest do
  use ExUnit.Case

  import Maxine.Compose
  alias Maxine.Machine

  setup do
    m1 = %Machine{
      initial: :on,
      transitions: %{
        power: %{
          on: :off,
          off: :on
        },
        foo: %{
          off: :foo
        }
      },
    }
    
    m2 = %Machine{
      initial: :foo,
      transitions: %{
        foo: %{
          on: :bar
        }
      }
    }

    merged = compose([m1, m2])

    %{m1: m1, m2: m2, merged: merged}
  end

  describe "compose/1" do
    test "returns a machine", %{merged: merged} do
      assert %Machine{} = merged
    end
      
    test "deep merges struct components", %{merged: merged} do
      assert merged.transitions.foo.off == :foo
      assert merged.transitions.foo.on == :bar
    end

    test "m2 gets preference", %{merged: merged, m2: m2} do
      assert merged.initial == m2.initial
    end

    test "handles case of a single machine, or list thereof", %{m1: m1} do
      assert compose(m1) == m1
      assert compose([m1]) == m1
    end

    test "raises on non-machine" do
      assert_raise ArgumentError, fn -> compose("foo") end
      assert_raise ArgumentError, fn -> compose(["foo"]) end
    end
  end
end
