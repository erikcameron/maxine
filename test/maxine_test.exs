defmodule MaxineTest do
  use ExUnit.Case
  doctest Maxine
  doctest Maxine.Callbacks

  import Maxine

  alias Maxine.State

  alias Maxine.Errors.{
    NoSuchEventError,
    UnavailableEventError,
    NoSuchCallbackError,
    CallbackReturnError,
    CallbackError,
#    MachineError
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

    test "generates state when optional callbacks/groups not given" do  
      params = Package.machine 
        |> Map.from_struct
        |> Map.drop([:callbacks, :groups])

      assert %State{} = Maxine.Machine |> struct(params) |> generate
    end
  end

  describe "advance/3" do 
    setup do
      {:ok, state} = Package.machine
        |> generate
        |> advance(:ship) 

      %{state: state}
    end

    test "returns a state", %{state: state} do
      assert %State{} = state
    end

    test "returns a state when optional callbacks/groups not given" do
      params = Package.machine 
        |> Map.from_struct
        |> Map.drop([:callbacks, :groups])

      assert {:ok, %State{}} = Maxine.Machine 
        |> struct(params) 
        |> generate
        |> advance(:ship)
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

    test "advances on group name for current state", %{state: state} do
      {:ok, returned_state} = advance(state, :return)
      assert returned_state.name == :origin
    end

    test "advances on glob mapping (i.e., event matches every from state)", %{state: state} do
      {:ok, under_inspection_state} = advance(state, :inspect)
      assert under_inspection_state.name == :under_inspection
    end

    test "returns NoSuchEventError on non-existent event", %{state: state} do
      assert {:error, %NoSuchEventError{}} = advance(state, :transmogrify)
    end

    test "returns UnavailableEventError on unavailable event", %{state: state} do
      assert {:error, %UnavailableEventError{}} = advance(state, :confirm)
    end

    # note that this test confirms a whole number of things:
    # - callbacks are fired
    # - callbacks are fired in the correct order
    # - state and event groups, and globs for each, are fired correctly 
    # - callbacks can write to data
    # - callbacks can write to data via Callbacks.merge_data/3
    # The last point particularly seems worthy of its own test,
    # but it seems a tad obsessive to rig up an entirely different
    # IO plan to separate those assertions when (a) you have state.data
    # right there, (b) you need to test it anyway and (c) it should 
    # always be available, to every callback.
    #
    # Maybe in the future.
    test "fires all 9 callback points in correct order (and Callbacks.merge_data/3 works)", %{state: state} do
      {:ok, state2} = advance(state, :ship)
      assert state2.data.app[:order] == [8, 7, 6, 5, 4, 3, 2, 1, 0]
    end     

    test "passes options to callbacks", %{state: state} do
      lament = "woe is my package"
      {:ok, lost_state} = advance(state, :lost, lament: lament)
      assert lost_state.data.app[:lament] == lament
    end 
    
    test "callbacks can halt chain by returning %CallbackError{}", %{state: state} do
      {:ok, delivered_state} = advance(state, :ship) 
      assert {:error, %CallbackError{}} = advance(delivered_state, :confirm)
    end

    test "non-existent callback blows up with NoSuchCallbackError" do
      doomed_state = generate(Package.machine)
      assert {:error, %NoSuchCallbackError{}} = advance(doomed_state, :lost)
    end

    test "illegal callback return blows up with CallbackReturnError" do
      doomed_state = generate(Package.machine)
      assert {:error, %CallbackReturnError{}} = advance(doomed_state, :weigh)
    end

    # Automatic advance 
    #
    # As above, we're sort of testing both the logic in the Maxine API, and
    # the request/3 and merge_data/3 functions, because that's how our testing
    # callbacks . Perhaps not entirely ideal but riddle me this: We want to keep
    # the implementation of the event request (i.e., what map will have what keys
    # set with the event name and event options respectively) from leaking,
    # including into this test. That implementation is hidden by Callbacks.request/3. 
    # If we reimplement it here to keep this a "unit test" don't we run the risk
    # of falling out of sync with our own API? Isn't it better to just use
    # Callbacks.request/3 here, and having done so, consider _it_ tested as well?
    #
    # (Will also note here that this test demonstrates that advance/3 was called
    # recursively, and returned the value generated by the recursion; hence no error
    # tests on auto-advance cases, because we've already tested the error handling
    # of advance/3 at some length above.)
    test "advances when callback requests next event (and Callbacks.request/3 works)" do
      {:ok, state} = advance(generate(Package.machine), :automate)
      assert state.name == :delivered
      assert state.data.options[:robot] == "yes"
    end

#    Not actually sure this is how we want to handle it...
#    test "errors from invalid machines are caught and reraised as MachineError" do
#      doomed_machine = %Machine{
#        initial: [],
#        transitions: "foo",
#        callbacks: "bar",
#        groups: nil
#      }
#      doomed_state = generate(doomed_machine)
#      assert {:error, %MachineError{}} = advance(doomed_state, :big_event)
#    end
  end 
end
