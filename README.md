# Maxine

A minimal state machine implemented as a data structure and various functions
thereon, rather than a separate agent with internal state, flow control, etc.

## Parts

1. The machine itself, %Machine: details the states, transition
uvents, callbacks and so on. (specify type/struct)
2. The API: A set of functions that operate on the data structure in (1): `trigger`
and so forth (functions)
3. The local machine state: API methods take and return instances of %MachineState (type/struct)

It seems like the client should be ultimately responsible for extracting the 
current state and merging the new state back in, because that requires knowledge
of the internals of that particular application state. Like, it shouldn't matter
to _this_ code if the caller keeps their MachineState behind a map key, or 
dynamically generates it via a function or something; same for how the new state
gets captured. (THAT SAID: We should provide a simple example of usage?)


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
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

