defmodule Maxine.Examples do
  ### Package: The postal experience

  defmodule PackageWorkflow do
    @moduledoc """
    Example Ecto-based workflow.
    """

    use Maxine.Workflow

    defmodule Ship do
      @behaviour Maxine.Workflow.Filter

      def filter(changeset, _options) do
        Ecto.Changeset.cast(changeset, %{name: "filtered"}, [:name])
      end
    end

    defmodule InTransit do
      @behaviour Maxine.Workflow.Filter

      def filter(changeset, _options) do
        name = Ecto.Changeset.get_field(changeset, :name)
        Ecto.Changeset.cast(changeset, %{name: "#{name} and appended"}, [:name])
      end
    end

    def machine, do: Maxine.Examples.Package.machine
    def events, do: %{ ship: Ship }
    def states, do: %{ in_transit: InTransit }
  end

  defmodule PackageCB do
    @moduledoc """
    Callback functions for the Package state machine.
    """

    import Maxine.Callbacks
    alias Maxine.{Machine, Data}
    alias Maxine.Errors.CallbackError
  
    def no_longer_in_transit(_, _, _, %Data{} = data), 
      do: merge_data(data, :app, %{order: [0]})  
    def left_shipping(_, _, _, %Data{} = data), 
      do: merge_data(data, :app, %{order: [1 | data.app[:order]]})  
    def all_leaving(_, _, _, %Data{} = data), 
      do: merge_data(data, :app, %{order: [2 | data.app[:order]]})  
    def now_delivered(_, _, _, %Data{} = data), 
      do: merge_data(data, :app, %{order: [3 | data.app[:order]]})  
    def entered_shipping(_, _, _, %Data{} = data), 
      do: merge_data(data, :app, %{order: [4 | data.app[:order]]})  
    def all_entering(_, _, _, %Data{} = data), 
      do: merge_data(data, :app, %{order: [5 | data.app[:order]]})  
    def on_ship(_, _, _, %Data{} = data), 
      do: merge_data(data, :app, %{order: [6 | data.app[:order]]})  
    def moved_around(_, _, _, %Data{} = data), 
      do: merge_data(data, :app, %{order: [7 | data.app[:order]]})  
    def all_events(_, _, _, %Data{} = data), 
      do: merge_data(data, :app, %{order: [8 | data.app[:order]]})  

    @spec log(Machine.state_name, Machine.state_name, Machine.event_name, %Data{}) :: %Data{}
    def log(from, to, event, %Data{} = data) do
      log_entry       = %{from: from, to: to, event: event}
      transition_log  = data.app[:transition_log] || []
      merge_data(data, :app, %{transition_log: [log_entry | transition_log]})
    end

    @spec lament(Machine.state_name, Machine.state_name, Machine.event_name, %Data{}) :: %Data{}
    def lament(_, _, _, %Data{} = data) do
      merge_data(data, :app, %{lament: data.options[:lament]})
    end

    # @spec halting_callback(Machine.state_name, Machine.state_name, Machine.event_name, %Data{}) :: %Data{}
    def halting_callback(_, _, _, _), do: %CallbackError{message: "halted"}
    
    def misguided_return(_, _, _, _), do: "foo!"

    # For testing automatic event firing
    def delivery_robot(_, _, _, %Data{} = data) do
      request(data, :delivered_by_robot, robot: "yes")
    end
  end 

  defmodule Package do
    @moduledoc """
    The Package state machine itself.
    """ 

    alias Maxine.Machine
    import PackageCB

    @machine %Machine{
      initial: :origin,
      transitions: %{ 
        weigh: %{
          origin: :weighed
        },
        ship: %{ 
          origin: :in_transit, 
          in_transit: :delivered 
        }, 
        inspect: %{ 
          *: :under_inspection 
        },
        return: %{
          shipped: :origin
        },
        lost: %{
          *: :under_the_couch,
          in_transit: :gone_away_to_the_forever_hole
        },
        confirm: %{
          delivered: :confirmed
        },
        automate: %{
          origin: :robot_delivery
        },
        delivered_by_robot: %{
          robot_delivery: :delivered
        }
      },
      groups: %{
        in_transit: :shipped,
        delivered: [:shipped],
        ship: :move_around,
      },
      callbacks: %{
        entering: %{ 
          delivered: :now_delivered,
          shipped: :entered_shipping,
          gone_away_to_the_forever_hole: :lament,
          under_the_couch: :non_existent_callback,
          weighed: :misguided_return_value,
          *: :all_entering,
        },
        leaving: %{ 
          in_transit: :no_longer_in_transit,
          shipped: :left_shipping,
          *: :all_leaving,
        },
        events: %{ 
          ship: :on_ship,
          move_around: :moved_around,
          confirm: :halting_callback,
          automate: :delivery_robot,
          *: [:all_events, :log]
        },
        index: %{
          no_longer_in_transit: &no_longer_in_transit/4,
          left_shipping: &left_shipping/4,
          all_leaving: &all_leaving/4,
          now_delivered: &now_delivered/4,
          entered_shipping: &entered_shipping/4,
          all_entering: &all_entering/4,
          on_ship: &on_ship/4,
          moved_around: &moved_around/4,
          all_events: &all_events/4,
          lament: &lament/4,
          halting_callback: &halting_callback/4,
          misguided_return_value: &misguided_return/4,
          delivery_robot: &delivery_robot/4, 
          log: &log/4
        }
      }
    }

    @spec machine() :: %Machine{}
    def machine(), do: @machine
  end

  ### Counter: demonstrate recursion (and TCO) with request/3

  defmodule CounterCB do
    import Maxine.Callbacks
    alias Maxine.Data

    def counter(_, _, _, %Data{} = data) do
      max    = data.options[:max] || 100
      iter   = data.app[:counter] || 1
      data 
      |> merge_data(:app, %{counter: iter + 1})
      |> run_or_stop(max)
    end

    defp run_or_stop(%Data{} = data, max) do
      if data.app[:counter] == max do
        data
      else
        request(data, :run, data.options)
      end
    end
  end

  defmodule Counter do
    import CounterCB
    alias Maxine.Machine

    @machine %Machine{
      initial: :stopped,
      transitions: %{
        run: %{
          stopped: :running,
          running: :running,
        },
        stop: %{
          running: :stopped
        }
      },
      groups: %{},
      callbacks: %{
        entering: %{},
        leaving: %{},
        events: %{
          run: :counter
        },
        index: %{
          counter: &counter/4
        }
      }
    }

    @spec machine() :: %Machine{}
    def machine(), do: @machine
  end
end
