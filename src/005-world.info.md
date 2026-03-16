# src/005-world.c

## Purpose
World state management for the pachinko machine. Handles creation,
initialization, cleanup, peg generation, and rendering of world state.

## External Functions

### world_create
```c
World* world_create(int width, int height)
```
**Description:** Creates and initializes a new world

**Parameters:**
- `width`: Screen width in pixels
- `height`: Screen height in pixels

**Returns:** World pointer on success, NULL on allocation failure

**Behavior:**
- Allocates World structure
- Initializes dimensions (width, height)
- Sets peg and zone arrays to NULL
- Sets counters to 0
- Sets initial score to 0
- Returns NULL and prints error on allocation failure

---

### world_destroy
```c
void world_destroy(World* world)
```
**Description:** Destroys a world and frees all resources

**Parameters:**
- `world`: World instance to destroy

**Returns:** void

**Behavior:**
- Returns early if world is NULL
- Frees peg array if allocated
- Frees zone array if allocated
- Frees world structure itself
- Safe to call with NULL pointer

---

### world_generate_pegs
```c
void world_generate_pegs(World* world, int rows, int cols,
                         float start_x, float start_y, float spacing)
```
**Description:** Generates a staggered peg grid in the world

**Parameters:**
- `world`: World instance
- `rows`: Number of peg rows
- `cols`: Number of pegs per row
- `start_x`: Starting x position for grid
- `start_y`: Starting y position for grid
- `spacing`: Distance between pegs in pixels

**Returns:** void

**Behavior:**
- Frees existing peg array if present
- Allocates new peg array (rows * cols)
- Generates staggered grid pattern
- Odd rows offset by half-spacing for zigzag effect
- Sets each peg's position and radius (PEG_RADIUS)
- Prints error to stderr on allocation failure

---

### world_render_pegs
```c
void world_render_pegs(World* world)
```
**Description:** Renders all pegs in the world as light gray circles

**Parameters:**
- `world`: World instance

**Returns:** void

**Behavior:**
- Returns early if world or pegs are NULL
- Renders each peg using raylib DrawCircle
- Uses LIGHTGRAY color
- Draws circles at peg position with peg radius
