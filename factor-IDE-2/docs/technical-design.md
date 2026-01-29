# Factor IDE 2 - Technical Design Document

## Overview

Factor IDE is a visual programming environment that uses factory-and-conveyor-belt
mechanics (inspired by Factorio and Beltmatic) as the interface metaphor for
composing and editing programs. Functions are represented as factories on a 2D grid.
Data flows between them on conveyor belts as Lua tables. Double-clicking a factory
opens a real terminal emulator (PTY) inside the game window, running the user's
preferred text editor on that factory's source file.

## Core Abstractions

### Factory
A factory is a visual node placed on the grid. It maps 1:1 to a Lua source file
containing a single function. Every factory function follows the same calling
convention:

```lua
-- takes: an anonymous function (or function pointer), and a table of arguments
-- returns: a table (always a tuple)
return function(fn, args)
  -- user-defined logic
  return { result_1, result_2 }
end
```

The constraint that every factory takes `(fn, args)` and returns a table enforces
a uniform interface. The `fn` parameter allows higher-order composition: a factory
can call the function passed to it, enabling pipelines, map operations, and
recursion through the belt network.

### Conveyor Belt
A belt is a directional connection between two factories. It carries a Lua table
from the output side of one factory to the input side of another. Belts are the
only way data moves between factories. Visually, items (table entries) travel
along the belt at a configurable tick rate.

### Grid
The world is a 2D tile grid. Factories occupy one or more tiles. Belts occupy
tiles between factories and have a direction (up/down/left/right). The grid is
the spatial layout that determines which factories connect to which.

### Terminal / PTY
When a factory is selected and opened, a real pseudo-terminal is spawned inside
the game window. This PTY runs the user's `$EDITOR` (or a configured default)
with the factory's source file loaded. The PTY is rendered as a texture in Love2D
using a character grid, receiving input from the game's keyboard handler while
the terminal is focused.

## Technology Stack

| Layer            | Choice                  | Rationale                                       |
|------------------|-------------------------|-------------------------------------------------|
| Language         | Lua (LuaJIT-compatible) | Project preference; Love2D is Lua-native         |
| Rendering        | Love2D                  | Fast 2D, immediate-mode drawing, Lua-native      |
| Terminal         | Real PTY (posix_openpt) | Authentic editor experience, no emulation gaps    |
| PTY binding      | LuaJIT FFI              | Direct C calls, no external Lua C modules needed  |
| Data transport   | Live Lua tables         | In-process, zero-copy where possible              |

## Data Flow Model

1. A factory's output belt holds a reference to the returned table.
2. On each simulation tick, items advance one tile along the belt.
3. When an item reaches a factory's input tile, it is queued for that factory.
4. The factory executes when all required inputs are present.
5. The returned table is placed on the factory's output belt.

Belt speed, factory execution order, and queue depth are all configurable per
factory or globally.

## PTY Integration Design

The embedded terminal is the most technically demanding component. The approach:

1. `posix_openpt()` via LuaJIT FFI to allocate a PTY master/slave pair.
2. `fork()` a child process that `exec`s the user's editor on the factory file.
3. The master fd is read each frame; output bytes are parsed (VT100/ANSI) and
   rendered to a character-cell texture in Love2D.
4. Keyboard input, while the terminal is focused, is written to the master fd.
5. On editor exit, the PTY is closed and the factory's source file is reloaded
   and re-evaluated to pick up changes.

## Input Handling

Two modes, similar to vim:

- **Grid mode**: Arrow keys / hjkl navigate the grid. Place factories, draw belts,
  select and inspect nodes. Keyboard-driven with optional mouse support.
- **Terminal mode**: All input is forwarded to the focused PTY. Escape or a
  configurable key returns to grid mode.

## File Layout Per Factory

Each factory corresponds to:
- `src/factories/{name}.lua` - the function source
- `src/factories/{name}.info.md` - external function signature doc (inputs/outputs)

## Open Questions

These are questions that remain to be resolved as development progresses:

1. **Belt merging/splitting**: Can belts merge (many-to-one) or split (one-to-many)?
   If so, what are the semantics? Round-robin? Broadcast? Priority?
2. **Error handling on belts**: If a factory errors, does the belt stall? Does an
   error item propagate downstream?
3. **Persistence format**: How is a grid layout saved? A single Lua table? JSON?
   A custom format?
4. **PTY rendering performance**: Rendering a full terminal at 60fps inside Love2D
   needs profiling. May need a dedicated canvas that only redraws on PTY output.
5. **Multi-factory editing**: Can multiple terminals be open simultaneously?
6. **Science packs / upgrades**: The vision mentions these as future possibilities.
   What would they represent in a programming context? (Linters? Type checkers?
   Optimizers?)
