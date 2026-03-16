# 006 - Build Instructions

## Prerequisites

### Raylib
Install raylib development files:

**Void Linux:**
```bash
sudo xbps-install -S raylib-devel
```

**Ubuntu/Debian:**
```bash
sudo apt install libraylib-dev
```

**From source:**
```bash
git clone https://github.com/raysan5/raylib.git
cd raylib/src
make PLATFORM=PLATFORM_DESKTOP
sudo make install
```

### Build Tools
- GCC or Clang
- Make
- pthreads (usually included with libc)

## Building

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
CFLAGS = -Wall -Wextra -std=c11 -I./src
LDFLAGS = -lraylib -lm -lpthread

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
