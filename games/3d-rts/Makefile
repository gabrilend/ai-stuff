# Makefile — Build the 3d-rts game binary.
#
# Targets:
#   all    — compile every C file under src/ into tmp/3d-rts.
#   clean  — remove generated artifacts under tmp/.
#   run    — build then launch the binary.
#
# Output goes to $(DIR)/tmp/, which is a symlink to /tmp/3d-rts/ on this
# machine — the project's tmp/ is intentionally volatile scratch space.
# Putting build artifacts there means a reboot wipes them along with
# anything else transient, and there is no chance of accidentally
# committing a binary.
#
# DIR is the project root. Override on the command line or in the
# environment if the project has been moved (e.g. `make DIR=/elsewhere`).
# Every path inside this Makefile is derived from $(DIR) so the build
# works no matter where it is invoked from. The reason for the explicit
# default rather than `$(CURDIR)`: the mono-repo's scripts can call
# `make -C $(DIR)` to build from any working directory, and a hard-coded
# fallback means a typo in -C still produces a well-defined location.

DIR ?= /mnt/mtwo/programming/ai-stuff/games/3d-rts

CC      := cc
CSTD    := -std=c11
WARN    := -Wall -Wextra -Wpedantic
OPT     := -O2 -g
DEFS    := -DGAME_DIR=\"$(DIR)\"
CFLAGS  := $(CSTD) $(WARN) $(OPT) $(DEFS)
LDFLAGS := -lraylib -lpthread -lm

SRC_DIR := $(DIR)/src
OUT     := $(DIR)/tmp
BIN     := $(OUT)/3d-rts
SRCS    := $(wildcard $(SRC_DIR)/*.c)

.PHONY: all clean run

all: $(BIN)

# A single-shot compile of all source files. Phase 1 is small enough
# that incremental object files are not yet earning their keep; if
# compile times start to bite, switch to per-file .o targets at that
# point and not before.
$(BIN): $(SRCS) | $(OUT)
	$(CC) $(CFLAGS) $(SRCS) -o $(BIN) $(LDFLAGS)

# `mkdir -p` on a symlink target is fine — it ensures /tmp/3d-rts/
# exists even if the volatile parent has been wiped between sessions.
$(OUT):
	mkdir -p $(OUT)

# Remove only the binary, not the whole tmp/ — other ad-hoc test
# artifacts (e.g. tmp/test-coroutine-pool) live there too and should
# survive a `make clean`.
clean:
	rm -f $(BIN)

run: $(BIN)
	$(BIN)
