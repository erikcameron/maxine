# Maxine 
[![Build Status](https://travis-ci.com/erikcameron/maxine.svg?branch=main)](https://travis-ci.com/erikcameron/maxine)

State machines as data, for Elixir. Includes lightweight Ecto integration.

## What's new

- *0.2.4* Bug fixes
- *0.2.3* Composable machines
- *0.2.2* Ecto integration

## About

After shopping for a simple Elixir state machine package, I liked 
the approach of [Fsm](https://github.com/sasa1977/fsm), in that
it eschews `gen_fsm`'s abstraction of a separate process in favor of a simple
data structure and some functions on it. That said, I had two concerns: 
1. I'd have to roll my own solution for callbacks, which, ok, but:
2. Fsm is largely implemented in macros, so as to provide a friendly
DSL for specifying machines inside of module definitons. Which is
great if that's what you need, but the code is frankly difficult
to understand, or at least more difficult ([and more metaprogramming](https://github.com/christopheradams/elixir_style_guide#metaprogramming))
than the simplicity of the task seems to warrant. Furthermore, the
resulting representation of the machines _themselves_ consists of
idiosyncratic DSL code which gets confusing after a while.

Maxine aims to be readable by design. It specifies a data type for
state machines instead: They are maps of a certain shape (a
`%Maxine.Machine{}`) that lay out rules for how other maps of a
certain shape (`%Maxine.State`) may be transformed. Note that the
nice clean `%{data: nil, state: foo}` that Fsm functions return
only serve the purpose of the latter. Fsm's actual representation
of events, states and transitions is obscured by the layer of
metaprogramming. In the documentation on ["Dynamic
definitions"](https://github.com/sasa1977/fsm#dynamic-definitions), the
example defines states and transitions via a simple keyword list,
but only the better to feed them to the macros. Maxine makes the
simple representation the canonical one, and exposes it.

That last clause is important: Presumably many/most state machine
libraries in many/most languages have a data type for a collection
of transitions, events and states, and/or implement it with a simple
associative structure like a map. The thing here is that instead
of treating that structure as an implementation detail, and hiding it
behind an API, we expose it, and make _it_ the interface. Benefits include:
- Easier to read and reason about than machines specified in an idiosyncratic DSL, at least for my brain
- Machines can be specified any way you like, at compile- or runtime
- Really easy to serialize and send over the network to databases, 
other languages/platforms, etc.

This train of thought began a few years ago working on a Rails
application that involved writing (a) machines with the
[state_machine](https://github.com/state-machines/state_machines)
DSL, and (b) [Elasticsearch](https://elastic.co) queries with whatever I wanted, because
they're plain old JSON objects. (The ES "Query DSL" really just
lays out the legal shapes for those objects; as they say in the
documentation, ["think of the Query DSL as an AST (Abstract Syntax
Tree) of
queries"](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html).
So maybe think of Maxine as an AST of state machines.)

Maybe more importantly: The Ruby DSL had decent surface clarity,
but as the machines became more complicated it seemed like I
systematically understood the ES queries better than I understood
the state transitions written in the DSL. Building basic data
structures was certainly easier than dealing with a class-level
DSL; in this case, data was easier to understand than code.  Hence
"state machines as data."

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
    groups: %{
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
        start_billing: fn(from, to, event, data) -> meter_on(data) end,
        stop_billing: fn(from, to, event, data) -> meter_off(data) end,
        log_event: fn(from, to, event, data) -> log("#{event} happened") end
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
# the second param to generate is an optional initial
# state; e.g., we could:
#   state = generate(MyMachine, :on)
# It's not going to make sure the state exists, so 
# be careful. :)
state = generate(MyMachine)
state.name == :off   # <=== true

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
    tmp: %{},     # like above, but wiped on every event
    options: []   # the keyword list of arguments passed to the most recent event
  }
}
```

## Moving parts

Machines are described in the following terms:

- <strong>States:</strong> States are identified by names, written
as atoms. The initial state is given by the machine (or by the
optional argument to `generate/2`, mainly for testing.)
- <strong>Events:</strong> Events are also identified by names,
written as atoms. These are provided as arguments to `advance/3`
and `advance!/3`, and form the keys in the machine's transition
tables.
- <strong>Transitions:</strong> The value of each event key is
itself a map that keys one state (or a group, or `*` to match any state) `A` to another
`B`, and denotes this event will transform a state `A` into a state
`B`.
- <strong>Callbacks:</strong> Callbacks are functions that the machine
runs on a given transition and that filter a `%Data{}` object in some way.
They may be specified in the following ways,
in the order in which they will be run:
    * On entering a given state (or a group, or `*`)
    * On leaving a given state (or a group, or `*`)
    * On firing a given event (or a group, or `*`)
Maxine has no concept of "before" or "after" a state change has
occurred, though you can implement your own such system using the
hooks above.
- <strong>Groups:</strong> States and events may also belong to groups;
the keys in the group table are names of (concrete, "real") states and 
events, and the values are one or more group names for that concrete
state. In the example above, `:not_on` is a group name for `:off` and
`:inoperative`. Group names are used in two places: 
    * As the "from" or "current" state in a transition mapping; i.e., 
    "this event moves from any state in group G to some concrete state S"
    * As aliases for states and events in the callback table; i.e., 
    "when entering/leaving any state in group G, or firing any event in
    group G, run this callback"

Note that groups can't be used to denote a "to" state, because denoting
only the group doesn't tell Maxine what concrete state you actually want;
they can't be used to denote events for the same reason. 

## The transition process

When an event is called on a given state, the following steps are performed
by `advance/3` and friends:
- The machine to consult is provided by the state itself (as `state.machine`)
- If the event name is not also a key in the machine's transitions table,
a `NoSuchEventError` is returned; otherwise we consult the specific
table for that event.
- In that table, we then look for an entry for the current state; if one exists,
it will denote the state to transition to. If not, we then look for entries
under each group name (if any) specified for this state, in the order
given in the machine, and finally under `*`. If none of these yield a 
next state, we return `UnavilableEventError`. 
- If we find a state name to transition to, we build a new `%State{}` record 
with:
    * the same `%Machine{}` as the current state
    * `name` set to the name of the new state
    * `previous` set to the name of the current state
    * A new `data` that inherits `data.app` from the current state,
    but gets a fresh `data.tmp` and `data.options` set to whatever options
    the event was called with (or an empty keyword list)
- Once the new state record is built, we create a list of callbacks to
run, in the order given above. (Group names are again triggered
in the order they are specified in the machine.) If we look at
`state.machine.callbacks` we'll see a map with four keys, `:entering`,
`:leaving`, `:events` and `:index`. Each of the first three in turn contains a map
where the keys are state names (`:entering`, `:leaving`) or event names
(`:events`), group names, or `*`; the values are names, written as
atoms, of callbacks. These names are the keys of the map under `index`, 
and the values of that map are actual functions. We use this extra layer 
of indirection for two reasons:
    * When using anonymous function literals, (rather than, e.g.,
    `&some_named_function/3`) you can associate them with multiple callback points
    and only specify them once; and
    * This makes the machines themselves (more) portable across platforms, languages,
    etc. The machine can be shared as, say, a plain JSON object with the callback
    index stripped; the host platform needs only to implement the named callbacks
    locally and the machine can then be shared freely.
A list of callback names is built, and then mapped over the index to create
a list of actual functions to call. If a missing callback is encountered
the result will be a `NoSuchCallbackError`. 
- The callbacks are called, each being given the name of the state
being exited, the state being entered, the event name, and a `%Data{}`
record, and being expected to return a new `%Data{}` object.
Callbacks do not have access to the state record! They rather
filter/intercept/"change" the `%Data{}` record, which is then passed
down the callback chain. (They cannot make illegal state changes,
and `data` aside, can't change any of the arguments provided to
other callbacks in this cycle. Note that event options are passed
in as `data.options`, so they _can_ filter those.) Callbacks may return `CallbackError`
instead to halt the event chain and return to the caller.
- If the callback chain terminates successfully, the resulting
`data` is merged back into state. At this point we check (in
`data.tmp`; see `Maxine.Callbacks.request/3`) if any callbacks have
requested that we automatically fire another event:
    * If not, `advance/3` returns `{:ok, state}` to the caller
    * If so, `advance/3` is called tail-recursively with the new event name and options, and we start
    the process again.

See the examples for concrete illustration.

## Ecto integration

Use `Maxine.Ecto.cast_state/4` to integrate with Ecto changesets thus:

```
some_record
|> cast_state(event, my_machine)
```

You can specify a field with the `field` option; default is `state`.
Will call `advance/3` on the basis of the record's current state 
and the given event, setting the value on the field or setting an
error on the changeset if the transition is invalid.

## Composition

Because machines are simple maps, you can compose them with a simple
deep merge. We use the (optional) dependency `deep_merge` for this. 
The interface:

```
Maxine.Compose.compose([machine1, machine2, ...])
```


## To do

- Fix Travis CI integration or move to something else


## Who's Maxine?

It's "machine," with an interpolated "x" for "Elixir." (Though if you have
a [favorite Maxine](https://en.wikipedia.org/wiki/Maxine_Waters) that's ok too)

## Installation

Maxine is [available in Hex](https://hex.pm/docs/publish), and can be installed
by adding `maxine` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:maxine, "~> 0.2.3"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/maxine](https://hexdocs.pm/maxine).

