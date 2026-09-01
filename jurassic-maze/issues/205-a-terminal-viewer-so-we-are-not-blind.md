# 205 — A Terminal Viewer So We Are Not Blind

| | |
| --- | --- |
| Phase | 2 — The Eye |
| Blocked by | 101, 102 |
| Blocks | nothing |
| Reads | [seeing it without a window](../docs/009-seeing-it-without-a-window.md) |
| Open questions | none |

## Current behavior

The maze can be seen in a window or measured as numbers, and there is nothing in
between.

## Intended behavior

One horizontal slice of the maze drawn as characters, stepping the simulation on
a keypress.

This is not a lesser window. It exists for the specific case where a number says
something is wrong and you need to see *where*, over ssh, with no graphics. The
window is worse at this, because in the window you have to find the thing first.

- One layer at a time, chosen by a key. Stone at that layer is a solid block
  character; a surface at that layer is a floor character; air is blank.
- Bodies as letters, one per creature kind, drawn at their stance.
- The header line says the layer, the tick, the body count, and the seed.
- It **holds at a gate**: it advances only when told. A simulation you can hold
  still is a simulation you can read.
- A key steps one tick; another runs until a named condition — a body gets stuck,
  a duel starts, the tick count reaches a number.

## Suggested implementation steps

1. Write the slice renderer as a function from store and layer to an array of
   strings, so it is testable without a terminal.
2. Write the body overlay as a second pass over the strings.
3. Write the gate loop: read a key, dispatch through a table of commands rather
   than a chain of comparisons.
4. Add the run-until conditions as named predicates in a table, so adding one is
   a row.
5. Test the slice renderer against a hand-built store with a known expected
   picture, as a literal block of text in the test file. A rendering test whose
   expectation is a picture is a test somebody can read.

## Related documents and tools

- [Seeing it without a window](../docs/009-seeing-it-without-a-window.md)
