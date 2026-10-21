# Phase 1 Progress

## Phase Goal

Core infrastructure: build system, threadpool, parallel processing, and configuration.

## Issues

| ID  | Description                        | Status    | Depends on |
|-----|------------------------------------|-----------|------------|
| 101 | Create Makefile build system       | completed | -          |
| 102 | Implement threadpool               | completed | -          |
| 103 | Create raylib window               | completed | -          |
| 104 | Create basic project structure     | completed | -          |
| 105 | Create local dependency build      | completed | -          |
| 106 | Detect system thread count         | completed | -          |
| 107 | Create ball task data structure    | completed | -          |
| 108 | Implement parallel ball update     | completed | -          |
| 109 | Implement synchronization barriers | completed | -          |
| 110 | Integrate parallel updates main    | completed | -          |
| 111 | Create performance benchmark       | completed | -          |
| 112 | Compile time config                | completed | -          |
| 113 | Config file self-edit              | completed | 112 ✓      |
| 114 | The lodge (front door, README)     | in-progress | -        |
| 114a | Picture the game                  | completed | -          |
| 114b | Lodge generator                   | completed | -          |
| 114c | The rooms                         | completed | 114a ✓, 114b ✓ |

## Progress Summary

Counts: run `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua
/mnt/mtwo/programming/ai-stuff/games/physics-sim -m`.

**Phase status:** in progress. The infrastructure of March is complete; the
lodge (114) is built and its three parts are done, and it stays open on
three questions: whether the game should learn to be driven by script,
whether its three warning-and-carry-on fallbacks should become errors, and
how the stale tickets the lodge's back shelf lists should be put right.

## Technical Notes

### Build System (101, 105)
- Makefile with automatic .c compilation
- DEBUG=1 flag support
- Local raylib dependency build script

### Threadpool (102, 106)
- Worker thread management
- Thread-safe circular buffer task queue
- Automatic CPU core detection

### Parallel Processing (107-111)
- BallTaskData struct for per-ball update parameters
- Threadpool distributes ball updates across worker threads
- Synchronization barriers ensure all updates complete before buffer swap
- Double-buffering prevents race conditions
- Performance benchmark validates scaling

### Configuration (112, 113)
- Compile-time configuration options (112)
- Config file self-edit: running `./config` opens it in $EDITOR (113)

### The lodge (114)
- Hand-written rooms in `lodge/pages/`, built by `lodge/build` into
  `docs/HTML/lodge/`; the rooms are the project's README
- `scripts/picture-the-game` photographs the game or the editor unattended
  and files each picture with notes into `development-history/`
- Lesson: the game's window takes the keyboard when it opens, so unattended
  pictures are only trustworthy while nobody types

## Issue-Level Dependencies

- 113 depends on 112 (compile-time config system) - 112 complete
- Foundation phase - provides infrastructure for all other phases
