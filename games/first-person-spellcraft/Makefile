# Makefile — build and run First Person Spellcraft.
#
# For the general: compiles the dataflow engine — its wires (slots), its thread
# pool, the graph dispatch, the raylib window seam, and the story main() — into
# one binary that lives in RAM-backed scratch, and offers to run the game or the
# substrate's own self-tests. Works launched from any directory (it locates
# itself from the Makefile's own path).

ROOT    := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))
PROJECT := first-person-spellcraft

# RAM tiers (house convention): the /tmp tier holds EXECUTABLE code, the /dev/shm
# tier holds non-executable artifacts/logs. /dev/shm is mounted noexec, so the
# binary must live in the /tmp tier (reached via the project-local tmp/ symlink);
# tmp/shared-memory stays reserved for logs and non-exec output.
EXEC_TMP := /tmp/$(PROJECT)
SHM      := /dev/shm/$(PROJECT)
BUILD    := $(ROOT)/tmp

CC      := gcc
CFLAGS  := -std=c11 -O2 -Wall -Wextra -pthread -I/usr/local/include
LDFLAGS := -L/usr/local/lib
LIBS    := -lraylib -lGL -lm -lpthread -ldl -lrt -lX11

ENGINE := $(ROOT)/libs/engine-core/slot.c \
          $(ROOT)/libs/task-pool/pool.c \
          $(ROOT)/libs/engine-core/graph.c \
          $(ROOT)/libs/platform/platform.c
MAIN   := $(ROOT)/src/000-main.c
BIN    := $(BUILD)/fps

.PHONY: all dirs run test clean

all: dirs $(BIN)

# Make sure the RAM scratch tiers + the tmp/shared-memory symlink exist before
# anything writes a build or a log there.
dirs:
	@mkdir -p $(EXEC_TMP) $(SHM)
	@[ -e $(ROOT)/tmp ] || ln -s $(EXEC_TMP) $(ROOT)/tmp
	@[ -e $(ROOT)/tmp/shared-memory ] || ln -s $(SHM) $(ROOT)/tmp/shared-memory

$(BIN): $(ENGINE) $(MAIN) | dirs
	$(CC) $(CFLAGS) $(ENGINE) $(MAIN) -o $(BIN) $(LDFLAGS) $(LIBS)

# Build + run the game. FPS_FRAMES (if set in the environment) auto-quits after
# N frames; unset means run until the window is closed.
run: all
	$(BIN) $(ROOT)

# Build + run the substrate self-tests. Tests are cheap — run them often.
test: dirs
	@echo "== slot =="  && $(CC) $(CFLAGS) $(ROOT)/libs/engine-core/slot.c  $(ROOT)/libs/engine-core/slot-test.c  -o $(BUILD)/slot-test  && $(BUILD)/slot-test
	@echo "== pool =="  && $(CC) $(CFLAGS) $(ROOT)/libs/task-pool/pool.c    $(ROOT)/libs/task-pool/pool-test.c    -o $(BUILD)/pool-test  && $(BUILD)/pool-test
	@echo "== graph ==" && $(CC) $(CFLAGS) $(ROOT)/libs/engine-core/slot.c $(ROOT)/libs/task-pool/pool.c $(ROOT)/libs/engine-core/graph.c $(ROOT)/libs/engine-core/graph-test.c -o $(BUILD)/graph-test && $(BUILD)/graph-test

clean:
	rm -f $(BUILD)/fps $(BUILD)/slot-test $(BUILD)/pool-test $(BUILD)/graph-test
