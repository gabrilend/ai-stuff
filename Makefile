# Makefile for Physics Simulator - Pachinko Machine
# Compiles C source files and links with raylib, pthreads, and system libraries
# Raylib is built locally via scripts/build-deps.sh
#
# Targets:
#   make game    - Build the game (default)
#   make editor  - Build the standalone board editor
#   make all     - Build both game and editor
#   make run     - Run the game
#   make clean   - Remove all build artifacts

CC = gcc
RAYLIB_PATH = ./libs/raylib/src
CJSON_PATH = ./libs/cjson
CFLAGS = -Wall -Wextra -std=c11 -I./src -I$(RAYLIB_PATH) -I$(CJSON_PATH)
LDFLAGS = $(RAYLIB_PATH)/libraylib.a -lm -lpthread

# Linux-specific libraries for raylib
LDFLAGS += -lGL -ldl -lrt -lX11

ifdef DEBUG
    CFLAGS += -g -O0 -DDEBUG
else
    CFLAGS += -O2
endif

# =============================================================================
# Game build (physics-sim)
# =============================================================================

GAME_SRCS = src/001-main.c \
            src/002-threadpool.c \
            src/005-world.c \
            src/007-ball.c \
            src/009-particles.c \
            src/011-upgrades.c \
            src/013-adversary.c \
            src/015-stage.c \
            src/017-ramp.c \
            src/019-expansion-anim.c \
            src/021-board-data.c \
            src/023-grid.c \
            src/027-stage-pool.c \
            src/029-portal.c \
            src/037-wrap-zones.c \
            src/039-slot-manager.c \
            src/041-spawner.c

GAME_OBJS = $(GAME_SRCS:.c=.o)
GAME_BIN = bin/physics-sim

# =============================================================================
# Editor build (board-editor)
# =============================================================================

EDITOR_SRCS = src/030-editor-main.c \
              src/032-editor-app.c \
              src/035-object-render.c \
              src/021-board-data.c \
              src/023-grid.c

EDITOR_OBJS = $(EDITOR_SRCS:.c=.o)
EDITOR_BIN = bin/board-editor

# =============================================================================
# Shared dependencies
# =============================================================================

CJSON_OBJ = $(CJSON_PATH)/cJSON.o

# =============================================================================
# Build targets
# =============================================================================

# Default: build game
game: $(GAME_BIN)

# Build editor
editor: $(EDITOR_BIN)

# Build both
all: game editor

$(GAME_BIN): $(GAME_OBJS) $(CJSON_OBJ)
	@mkdir -p bin
	$(CC) $(GAME_OBJS) $(CJSON_OBJ) -o $(GAME_BIN) $(LDFLAGS)

$(EDITOR_BIN): $(EDITOR_OBJS) $(CJSON_OBJ)
	@mkdir -p bin
	$(CC) $(EDITOR_OBJS) $(CJSON_OBJ) -o $(EDITOR_BIN) $(LDFLAGS)

# Pattern rule for compiling .c to .o
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# cJSON library compilation (fewer warnings)
$(CJSON_PATH)/cJSON.o: $(CJSON_PATH)/cJSON.c
	$(CC) -std=c11 -I$(CJSON_PATH) -O2 -c $< -o $@

# =============================================================================
# Utility targets
# =============================================================================

run: $(GAME_BIN)
	./$(GAME_BIN)

run-editor: $(EDITOR_BIN)
	./$(EDITOR_BIN)

clean:
	rm -f src/*.o $(CJSON_PATH)/*.o $(GAME_BIN) $(EDITOR_BIN)

.PHONY: all game editor run run-editor clean
