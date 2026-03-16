# src/005-world.c

## Purpose
World state management for the pachinko machine. Handles creation,
initialization, and cleanup of world state including pegs and score zones.

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
