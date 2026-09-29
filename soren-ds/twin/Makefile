# Soren DS — the laptop twin's build (issues 200, 304)
#
# General description: three stages. First the box generator is built on
# its own, from nothing but its own two files, and run over src/boxes/ and
# src/maps/ — it writes the catalogue, a header naming every box, and the
# maps as strings into the RAM work directory, replacing the previous ones
# only if it succeeds (a failed run leaves the last good catalogue in
# place). Then the portable half of the system (src/engine/, src/system/)
# and the laptop's own answers (twin/*.c) are compiled, with the generated
# files, into one library. Last, every test under twin/tests/ and every
# program under twin/programs/ is built against it. Three variants live
# side by side: "debug" (the engine survives a box that faults; what the
# tests use), "fast" (the ordinary build; what measurements use) and
# "asan" (the host's address checker; for hunting memory bugs). Nothing
# here touches the kernel build.
#
# Invoked through scripts/test-twin and the demo scripts, or directly:
#   make -C twin VARIANT=debug

DIR ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

TMP_REAL := $(shell readlink -f $(DIR)/tmp)
ifeq ($(TMP_REAL),)
$(error cannot resolve $(DIR)/tmp — the project expects tmp/ to be a symlink to its RAM-backed work directory)
endif

.DEFAULT_GOAL := all

VARIANT ?= debug
BUILD   := $(TMP_REAL)/build/twin-$(VARIANT)
GEN     := $(TMP_REAL)/build/generated
TOOLS   := $(TMP_REAL)/build/tools

HOST_CC := gcc
CC      := gcc
SDL_CFLAGS := $(shell pkg-config --cflags sdl2 2>/dev/null)
SDL_LIBS   := $(shell pkg-config --libs sdl2 2>/dev/null)
CFLAGS := -std=gnu11 -O2 -g -Wall -Wextra -Werror -pthread -fno-strict-aliasing \
          -I$(DIR)/src/engine -I$(DIR)/src/system -I$(DIR)/twin -I$(GEN) \
          $(shell pkg-config --cflags libpng 2>/dev/null)
# -rdynamic makes the engine's own functions visible to box code the twin
# compiles and loads at run time (issue 409); -ldl is the loader.
LDLIBS := -pthread -lm -ldl -rdynamic $(shell pkg-config --libs libpng 2>/dev/null)

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

# --- stage one: the generator and what it writes -----------------------
GENERATOR     := $(TOOLS)/generate
BOX_SOURCES   := $(sort $(wildcard $(DIR)/src/boxes/*.c))
MAP_SOURCES   := $(sort $(wildcard $(DIR)/src/maps/*.map))
CATALOGUE_C   := $(GEN)/catalogue.c
CATALOGUE_H   := $(GEN)/catalogue-boxes.h
MAPS_C        := $(GEN)/maps.c

$(GENERATOR): $(DIR)/twin/tools/061-generate.c $(DIR)/src/engine/060-generator.c $(DIR)/src/engine/060-generator.h
	@mkdir -p $(dir $@)
	@$(HOST_CC) -std=gnu11 -O2 -Wall -Wextra -Werror $(DIR)/twin/tools/061-generate.c $(DIR)/src/engine/060-generator.c -o $@

# The generated files depend on the program that writes them, not only on
# what it reads — change the generator and the catalogue is rebuilt.
$(CATALOGUE_C) $(CATALOGUE_H) &: $(BOX_SOURCES) $(GENERATOR)
	@mkdir -p $(GEN)
	@$(GENERATOR) --root $(DIR) --boxes $(DIR)/src/boxes --out $(CATALOGUE_C) --header $(CATALOGUE_H)

$(MAPS_C): $(MAP_SOURCES) $(GENERATOR)
	@mkdir -p $(GEN)
	@$(GENERATOR) --root $(DIR) --maps $(DIR)/src/maps --out $(MAPS_C)

.PHONY: describe-boxes
describe-boxes: $(GENERATOR)
	@$(GENERATOR) --root $(DIR) --boxes $(DIR)/src/boxes --describe

# --- stage two: the library --------------------------------------------
PORTABLE := $(shell find $(DIR)/src/engine $(DIR)/src/system -name '*.c' 2>/dev/null | sort)
SUPPORT  := $(sort $(wildcard $(DIR)/twin/*.c))
TESTS    := $(sort $(wildcard $(DIR)/twin/tests/*.c))
PROGRAMS := $(sort $(wildcard $(DIR)/twin/programs/*.c))

PORTABLE_OBJS := $(patsubst $(DIR)/%.c,$(BUILD)/obj/%.o,$(PORTABLE))
SUPPORT_OBJS  := $(patsubst $(DIR)/%.c,$(BUILD)/obj/%.o,$(SUPPORT))
GENERATED_OBJS := $(BUILD)/obj/generated/catalogue.o $(BUILD)/obj/generated/maps.o
LIB           := $(BUILD)/libsoren-twin.a

TEST_BINS    := $(patsubst $(DIR)/twin/tests/%.c,$(BUILD)/tests/%,$(TESTS))
PROGRAM_BINS := $(patsubst $(DIR)/twin/programs/%.c,$(BUILD)/programs/%,$(PROGRAMS))

HEADERS := $(shell find $(DIR)/src/engine $(DIR)/src/system $(DIR)/twin -name '*.h' 2>/dev/null) $(CATALOGUE_H)

.PHONY: all tests programs clean print-build generated

all: $(LIB) $(TEST_BINS) $(PROGRAM_BINS)
tests: $(TEST_BINS)
programs: $(PROGRAM_BINS)
generated: $(CATALOGUE_C) $(CATALOGUE_H) $(MAPS_C)

print-build:
	@echo $(BUILD)

$(BUILD)/obj/%.o: $(DIR)/%.c $(HEADERS)
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/obj/generated/catalogue.o: $(CATALOGUE_C) $(BOX_SOURCES) $(HEADERS)
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/obj/generated/maps.o: $(MAPS_C) $(HEADERS)
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -c $< -o $@

$(LIB): $(PORTABLE_OBJS) $(SUPPORT_OBJS) $(GENERATED_OBJS)
	@mkdir -p $(dir $@)
	@rm -f $@
	@ar rcs $@ $^

# --- stage three: tests and programs -----------------------------------
# Tests write small boxes by hand and leave the optional ordering field of
# a box record out; that omission is deliberate, so the warning is off here.
$(BUILD)/tests/%: $(DIR)/twin/tests/%.c $(LIB) $(HEADERS)
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -Wno-missing-field-initializers $< $(LIB) -o $@ $(LDLIBS)

# Programs may open a window, so they are the only things linked against
# SDL2; a machine without it can still build and run every test.
$(BUILD)/programs/%: $(DIR)/twin/programs/%.c $(LIB) $(HEADERS)
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) $(SDL_CFLAGS) $< $(LIB) -o $@ $(LDLIBS) $(SDL_LIBS)

clean:
	rm -rf $(BUILD) $(GEN) $(TOOLS)
