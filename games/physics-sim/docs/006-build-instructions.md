# 006 - Build Instructions

## Prerequisites

### Build Tools
- GCC or Clang
- Make
- Git
- pthreads (usually included with libc)

### OpenGL Development Headers
**Void Linux:**
```bash
sudo xbps-install -S mesa-devel libX11-devel
```

**Ubuntu/Debian:**
```bash
sudo apt install libgl1-mesa-dev libx11-dev
```

## Building

### First Time Setup
Build raylib locally (only needed once):
```bash
./scripts/build-deps.sh
```

This downloads and compiles raylib 5.0 into `libs/raylib/`.

### Compile the Project
From project root:
```bash
make
```

For debug build:
```bash
make DEBUG=1
```

For clean rebuild:
```bash
make clean && make
```

## Running

```bash
./bin/physics-sim
```

Or with make:
```bash
make run
```

## Project Structure

```
physics-sim/
├── src/
│   ├── 001-main.c          # Entry point, main loop
│   ├── 002-threadpool.c    # Threadpool implementation
│   ├── 003-threadpool.h    # Threadpool header
│   ├── 004-physics.c       # Ball physics
│   ├── 005-physics.h       # Physics header
│   ├── 006-world.c         # World state management
│   ├── 007-world.h         # World header
│   ├── 008-render.c        # Raylib rendering
│   └── 009-render.h        # Render header
├── docs/                   # Documentation
├── issues/                 # Issue tracking
├── assets/                 # Graphics/audio (if any)
├── libs/                   # External libraries
├── bin/                    # Build output
└── Makefile
```

## Makefile Template

```makefile
CC = gcc
RAYLIB_PATH = ./libs/raylib/src
CFLAGS = -Wall -Wextra -std=c11 -I./src -I$(RAYLIB_PATH)
LDFLAGS = $(RAYLIB_PATH)/libraylib.a -lm -lpthread

# Linux-specific
LDFLAGS += -lGL -ldl -lrt -lX11

SRC = $(wildcard src/*.c)
OBJ = $(SRC:.c=.o)
BIN = bin/physics-sim

ifdef DEBUG
    CFLAGS += -g -O0 -DDEBUG
else
    CFLAGS += -O2
endif

all: $(BIN)

$(BIN): $(OBJ)
	@mkdir -p bin
	$(CC) $(OBJ) -o $(BIN) $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

run: $(BIN)
	./$(BIN)

clean:
	rm -f src/*.o $(BIN)

.PHONY: all run clean
```
