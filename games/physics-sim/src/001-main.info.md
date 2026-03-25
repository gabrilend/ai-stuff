# src/001-main.c

## Purpose
Entry point for physics simulator. Initializes raylib window and threadpool,
runs main game loop, and handles clean shutdown.

## External Functions

### main
```c
int main(void)
```
**Description:** Program entry point

**Parameters:** None

**Returns:** 0 on success, 1 on error

**Behavior:**
- Creates threadpool with 4 workers and 64 task queue capacity
- Initializes 800x600 raylib window at 60fps
- Runs main rendering loop until window close requested
- Cleans up threadpool and raylib resources
- Prints status messages to stdout during lifecycle
