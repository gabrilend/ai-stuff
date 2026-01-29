# Factor IDE 2 - Roadmap

## Phase 1: Foundation

Establish the Love2D application skeleton, grid rendering, and camera system.

- Love2D project scaffolding (conf.lua, main.lua)
- Tile grid data structure and rendering
- Camera: pan and zoom across the grid
- Basic input handling (keyboard + mouse)
- Grid coordinate system (screen <-> tile conversion)

## Phase 2: Factories

Place and interact with factory nodes on the grid.

- Factory data model (name, position, source file path, input/output ports)
- Place factories on grid tiles via keyboard or mouse
- Render factory sprites/rectangles with labels
- Select factories (vim-style navigation: hjkl to cycle, Enter to select)
- Delete / move factories
- Factory port layout (input side, output side)

## Phase 3: Conveyor Belts

Draw directional belts connecting factory ports.

- Belt data model (list of tiles, direction per tile, source port, dest port)
- Belt drawing mode: select output port, trace path, connect to input port
- Belt rendering with directional animation (items sliding along)
- Belt routing: pathfinding or manual tile-by-tile placement
- Belt deletion and modification

## Phase 4: Data Flow Engine

Execute the factory network as a live Lua program.

- Factory function loader: load each factory's .lua file as a callable
- Tick-based simulation loop (separate from render loop)
- Belt item transport: advance items one tile per tick
- Factory execution: when inputs arrive, call `factory_fn(fn, args)`, place result on output belt
- Input factories (sources): manually push tables onto belts
- Output factories (sinks): display or log received tables
- Error handling: factory errors stall the belt and display the error visually

## Phase 5: PTY Integration

Embed a real terminal inside the Love2D window.

- LuaJIT FFI bindings for `posix_openpt`, `grantpt`, `unlockpt`, `ptsname`
- `fork()` + `exec()` to spawn editor process on factory source file
- Read PTY master fd each frame, buffer output bytes
- VT100/ANSI escape sequence parser (enough for common editors)
- Character-cell renderer: draw terminal text as a Love2D canvas/texture
- Keyboard forwarding: route input to PTY master fd in terminal mode
- Mode switching: grid mode <-> terminal mode
- On editor exit: close PTY, reload and re-evaluate factory source

## Phase 6: Factory File System

Manage factory source files and metadata on disk.

- Auto-create `src/factories/{name}.lua` with template on factory placement
- Auto-create `src/factories/{name}.info.md` with signature stub
- Hot-reload: detect file changes after editor closes, re-parse factory function
- Factory renaming: rename file + update all belt references
- Factory deletion: remove file + disconnect belts

## Phase 7: Persistence and Configuration

Save and load grid layouts; user configuration.

- Grid serialization format (Lua table written to file)
- Save/load full project state (factories, belts, positions, config)
- User configuration file: default editor, belt speed, tick rate, keybinds
- Undo/redo for grid operations (factory placement, belt drawing)

## Phase 8: Extensions

Advanced features beyond the core loop.

- Belt merging (many-to-one) and splitting (one-to-many) with configurable semantics
- "Science pack" concept: attach linters, type checkers, or analyzers to factories
- Factory grouping / sub-grids (zoom into a factory to see an inner belt network)
- Multiple simultaneous PTY windows
- Visual debugger: pause simulation, inspect belt contents, step one tick at a time
