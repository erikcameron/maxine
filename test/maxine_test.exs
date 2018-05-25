defmodule MaxineTest do
  use ExUnit.Case
  doctest Maxine

  test "greets the world" do
    assert Maxine.hello() == :world
  end
end
