# Maxine

State machines as data, for Elixir.
## About

After shopping for a simple Elixir state machine package, I liked 
the approach of [Fsm](https://github.com/sasa1977/fsm), in that
it eschews `gen_fsm`'s abstraction of a separate process in favor of a simple
data structure and some functions on it. That said, I had two concerns, 
which turned out to be related:
1. I'd have to roll my own solution for callbacks, which, ok, but:
2. Fsm is largely implemented in macros, so as to provide a friendly DSL
for specifying machines inside of module definitons. The code is frankly
difficult to understand, or at least more difficult (and more metaprogramming)
than the simplicity of the task seems to warrant. Furthermore, the
resulting representation of the machines _themselves_ consists of
idiosyncratic DSL code which gets confusing after a while.

Maxine specifies a data type for state machines instead: They are maps of
a certain shape (a `%Maxine.Machine{}`) that lay out rules for how other
maps of a certain shape (`%Maxine.State`) may be transformed. Note that the
nice clean `%{data: nil, state: foo}` that Fsm functions return only serve the 
purpose of the latter. Fsm's actual representation of events, states and 
transitions is obscured by the layer of metaprogramming. In the documentation
on ["Dynamic definitions"](https://github.com/sasa1977/fsm#dynamic-definitions),
the example defines states and transitions via a simple keyword list, but only
the better to feed them to the macros. Maxine makes the simple representation
the canonical one, and exposes it.

That last clause is important: Presumably many/most state machine
libraries in many/most languages have a data type for a collection
of transitions, events and states, and/or implement it with a simple
associative structure like a map. The thing here is that instead
of hiding that structure as an implementation detail, we make _it_
the contract, instead of a DSL, API, etc.

The line is thin anyway. This train of thought began a few years
ago working on a few Rails applications writing (a) machines with
the [state_machine](https://github.com/state-machines/state_machines)
DSL, and (b) Elasticsearch queries with whatever I wanted, because
they're JSON. (The ES "Query DSL" really just lays out the legal
formats; as they say in the documentation, ["think of the Query DSL
as an AST (Abstract Syntax Tree) of
queries"](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html).


The Ruby DSL had decent surface clarity, but as the machines became
more complicated it seemed like I systematically understood the
queries better than I understood the state transitions. Building
basic data structures was certainly easier than dealing with a
class-level DSL; the data was easier to understand than the code.
Hence "state machines as data."

## Basics

Typically you'll start by defining a machine, like so:

```elixir
defmodule MyMachine do
  alias Maxine.Machine

  @machine %Machine{
    initial: :off,
    transitions: %{
      power: %{
        on: :off,
        off: :on
      },
      blow_fuse: %{
        on: :inoperative
      },
    },
    aliases: %{
      off: :not_on,
      inoperative: [:not_on, :totally_fubar]
    },
    callbacks: %{
      entering: %{
        on: :start_billing,
      },
      leaving: %{
        on: :stop_billing
      },
      events: %{
        *: :log_event
      }
      index: %{
        start_billing: fn(state, event, data) -> meter_on(data) end,
        stop_billing: fn(s, e, d) -> meter_off(data) end,
        log_event: fn(s, e, d) -> log("#{event} happened") end
      }
    }
  }

  spec machine() :: %Machine{}
  def machine(), do: @machine
end
```

The public API gives three functions, `generate/2`, `advance/3` and
`advance!/3`. Use as follows:

```elixir
state = generate(MyMachine)
state.name == :off   # <=== true

# the second param to generate is an optional initial
# state; e.g., we could:
#   state = generate(MyMachine, :on)
# It's not going to make sure the state exists, so 
# be careful. :)

{:ok, %State{} = state2} = advance(state, :power, options_are: "optional")
# or
state2 = advance!(state, :power) # raises on any error

state2.name == :on  # <=== true

```

The `%State{}` struct represents an actual machine state,
and looks like this:

```
st = %State{
  name: :current_state_name,
  previous: :previous_state_name,
  machine: %Machine{...}
  data: %{
    app: %{},     # a spot for callbacks to put/get data
    tmp: %{},     # like above, but wiped every event
    options: []   # the keyword list of arguments passed to this event
  }
}
```

Stay tuned, and in the meantime see the test suite for more.




## Installation

Maxine is [available in Hex](https://hex.pm/docs/publish), and can be installed
by adding `maxine` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:maxine, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/maxine](https://hexdocs.pm/maxine).

