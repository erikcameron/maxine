defmodule MaxineTest do
  use ExUnit.Case
  doctest Maxine

  import Maxine

  alias Maxine.{
    Machine, 
    Data, 
    State
  }
  alias Maxine.Errors.{
    NoSuchEventError,
    BadMoveError,
    BadCallbackError,
    CallbackError,
    MachineError
  }  
    
  alias Maxine.Examples.Package

   
  describe "generate/2" do
    setup do
      %{state: generate(Package.machine)}
    end

    test "makes a valid state", %{state: state} do
      assert %State{} = state
    end
    
    test "has correct initial state", %{state: state} do
      assert state.name == :origin
    end
  
    test "rejects non-machines" do
      assert_raise FunctionClauseError, fn -> generate(%{foo: "bar"}) end
    end

    test "assigns initial state from argument" do
      assert generate(Package.machine, :foo).name == :foo
    end
  end


  describe "advance/3" do 
    setup do
      {:ok, state} = advance(generate(Package.machine), :ship)
      %{state: state}
    end

    test "advances via event legally with default options", %{state: state} do
      assert state.name == :in_transit
    end

    test "advances via event legally with passed options", %{state: state} do
      state2 = advance!(state, :ship, opt1: "foobar")
      assert state2.data.options[:opt1] == "foobar"
    end
    
    test "handles events with multiple mappings correctly", %{state: state} do
      {:ok, state3} = advance(state, :ship)
      assert state3.name == :delivered
    end

    test "advances on aliased mapping (i.e., event matches a state alias", %{state: state} do
      {:ok, returned_state} = advance(state, :return)
    end

    test "advances on glob mapping (i.e., event matches every from state)", %{state: state} do
      {:ok, under_inspection_state} = advance(state, :inspect)
    end

    test "returns NoSuchEventError on non-existent event", %{state: state} do
      assert {:error, %NoSuchEventError{}} = advance(state, :transmogrify)
    end

    test "returns BadMoveError on unavailable event", %{state: state} do
      assert {:error, %BadMoveError{}} = advance(state, :confirm)
    end

    # note that this test confirms a whole number of things:
    # - callbacks are fired
    # - callbacks are fired in the correct order
    # - state and event aliases, and globs for each, are fired correctly 
    # - callbacks can write to data
    # - callbacks can write to data via Callbacks.merge_data/3
    # The last point particularly seems worthy of its own test,
    # but it seems a tad obsessive to rig up an entirely different
    # IO plan to separate those assertions when (a) you have state.data
    # right there, (b) you need to test it anyway and (c) it should 
    # always be available, to every callback.
    test "fires all 9 callback points in correct order (and Callbacks.merge_data/3 works)", %{state: state} do
      state2 = advance!(state, :ship)
      assert state2.data.app[:order] == [8, 7, 6, 5, 4, 3, 2, 1, 0]
    end     

    test "passes options to callbacks", %{state: state} do
      lament = "woe is my package"
      {:ok, lost_state} = advance(state, :lost, lament: lament)
      assert lost_state.data.app[:lament] == lament
    end 
    
    test "callbacks can halt chain by returning %CallbackError{}", %{state: state} do
      {:ok, delivered_state} = advance(state, :ship) 
      {:error, %CallbackError{}} = advance(delivered_state, :confirm)
    end

    test "non-existent callback blows up with BadCallbackError" do
      doomed_state = generate(Package.machine)
      {:error, %BadCallbackError{}} = advance(doomed_state, :lost)
    end
  end 
end
