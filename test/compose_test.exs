defmodule Maxine.ComposeTest do
  use ExUnit.Case

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

    merged = Maxine.Compose.compose([m1, m2])

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
  end
end
