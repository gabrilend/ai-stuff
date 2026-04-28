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

# Vendored raylib (see scripts/deps/fetch-raylib.sh and the addendum
# on issue 101). Including the archive by absolute path rather than
# `-lraylib` so the linker cannot pick up a system-installed copy.
RAYLIB_DIR  := $(DIR)/libs/raylib
RAYLIB_ARCH := $(RAYLIB_DIR)/src/libraylib.a
RAYLIB_INCL := -I$(RAYLIB_DIR)/src

CFLAGS  := $(CSTD) $(WARN) $(OPT) $(DEFS) $(RAYLIB_INCL)

# raylib's static archive needs its system deps named explicitly.
# Order matters: the archive comes first, then the libraries it
# references. -lpthread is the system POSIX threads (cannot be
# vendored — it lives in glibc).
LDFLAGS := $(RAYLIB_ARCH) -lGL -lpthread -lm -ldl -lrt -lX11

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
#
# The raylib archive is a prerequisite so a missing or stale archive
# fails loudly — the right place to fix that is scripts/build.sh
# (which runs the dep fetch + build before this rule), not by
# papering over with an automatic rebuild here.
$(BIN): $(SRCS) $(RAYLIB_ARCH) | $(OUT)
	$(CC) $(CFLAGS) $(SRCS) -o $(BIN) $(LDFLAGS)

# Tell make where the archive comes from so a useful error message
# fires if scripts/build.sh has not been run first.
$(RAYLIB_ARCH):
	@echo "raylib archive not found at $@."
	@echo "Run scripts/build.sh to fetch and build vendored deps."
	@exit 1

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
