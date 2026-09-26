# Soren DS — the laptop twin's build (issue 200)
#
# General description: compile the portable half of the system (everything
# under src/engine/ and src/system/) with the laptop's own C compiler,
# together with the laptop's answers to the hardware questions (twin/*.c),
# into one library; then build every test under twin/tests/ and every
# program under twin/programs/ against it. Two variants live side by side
# in the RAM-backed work directory: "debug" (the engine survives a box that
# faults; what the tests use) and "fast" (the ordinary build; what the
# measurements use). Nothing here touches the kernel build.
#
# Invoked through scripts/build-twin and scripts/test-twin, or directly:
#   make -C twin VARIANT=debug

DIR ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

TMP_REAL := $(shell readlink -f $(DIR)/tmp)
ifeq ($(TMP_REAL),)
$(error cannot resolve $(DIR)/tmp — the project expects tmp/ to be a symlink to its RAM-backed work directory)
endif

VARIANT ?= debug
BUILD   := $(TMP_REAL)/build/twin-$(VARIANT)

CC     := gcc
SDL_CFLAGS := $(shell pkg-config --cflags sdl2 2>/dev/null)
SDL_LIBS   := $(shell pkg-config --libs sdl2 2>/dev/null)
CFLAGS := -std=gnu11 -O2 -g -Wall -Wextra -Werror -pthread -fno-strict-aliasing \
          -I$(DIR)/src/engine -I$(DIR)/src/system -I$(DIR)/twin $(shell pkg-config --cflags libpng 2>/dev/null)
LDLIBS := -pthread -lm $(shell pkg-config --libs libpng 2>/dev/null)

# The debug variant switches on the engine's fault catcher (issue 214):
# every box call runs under a snapshot the platform can return to.
ifeq ($(VARIANT),debug)
CFLAGS += -DSOREN_DEBUG
endif

# The asan variant is for hunting memory bugs: every block comes from the
# host's allocator (so the host's address checker can watch each one) and
# the checker is compiled in. Parking, which works on whole pages, is not
# meaningful in this variant.
ifeq ($(VARIANT),asan)
CC := clang
CFLAGS += -DSOREN_DEBUG -DSOREN_BLOCKS_FROM_HOST -fsanitize=address -fno-omit-frame-pointer
LDLIBS += -fsanitize=address
endif

PORTABLE := $(shell find $(DIR)/src/engine $(DIR)/src/system -name '*.c' 2>/dev/null | sort)
SUPPORT  := $(sort $(wildcard $(DIR)/twin/*.c))
TESTS    := $(sort $(wildcard $(DIR)/twin/tests/*.c))
PROGRAMS := $(sort $(wildcard $(DIR)/twin/programs/*.c))

PORTABLE_OBJS := $(patsubst $(DIR)/%.c,$(BUILD)/obj/%.o,$(PORTABLE))
SUPPORT_OBJS  := $(patsubst $(DIR)/%.c,$(BUILD)/obj/%.o,$(SUPPORT))
LIB           := $(BUILD)/libsoren-twin.a

TEST_BINS    := $(patsubst $(DIR)/twin/tests/%.c,$(BUILD)/tests/%,$(TESTS))
PROGRAM_BINS := $(patsubst $(DIR)/twin/programs/%.c,$(BUILD)/programs/%,$(PROGRAMS))

HEADERS := $(shell find $(DIR)/src/engine $(DIR)/src/system $(DIR)/twin -name '*.h' 2>/dev/null)

.PHONY: all tests programs clean print-build

all: $(LIB) $(TEST_BINS) $(PROGRAM_BINS)
tests: $(TEST_BINS)
programs: $(PROGRAM_BINS)

print-build:
	@echo $(BUILD)

$(BUILD)/obj/%.o: $(DIR)/%.c $(HEADERS)
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -c $< -o $@

$(LIB): $(PORTABLE_OBJS) $(SUPPORT_OBJS)
	@mkdir -p $(dir $@)
	@rm -f $@
	@ar rcs $@ $^

$(BUILD)/tests/%: $(DIR)/twin/tests/%.c $(LIB) $(HEADERS)
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) $< $(LIB) -o $@ $(LDLIBS)

# Programs may open a window, so they are the only things linked against
# SDL2; a machine without it can still build and run every test.
$(BUILD)/programs/%: $(DIR)/twin/programs/%.c $(LIB) $(HEADERS)
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) $(SDL_CFLAGS) $< $(LIB) -o $@ $(LDLIBS) $(SDL_LIBS)

clean:
	rm -rf $(BUILD)
