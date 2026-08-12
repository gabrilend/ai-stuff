# Soren DS — kernel build
#
# General description: compile every .c under src/ with the cross-
# compiler at libs/cross/bin/aarch64-elf-gcc, link the objects with
# the linker script at src/kernel.ld, and produce a raw kernel binary
# at output/kernel.img. Intermediate object files live in
# tmp/build/kernel/ — the project's RAM-backed work directory — so the
# SSD never sees them. Errors loudly when the toolchain isn't
# installed.
#
# Invoked either directly with `make` from the project root or
# through `scripts/build` from anywhere.

DIR ?= $(CURDIR)

CROSS_PREFIX := $(DIR)/libs/cross
CC      := $(CROSS_PREFIX)/bin/aarch64-elf-gcc
LD      := $(CROSS_PREFIX)/bin/aarch64-elf-ld
OBJCOPY := $(CROSS_PREFIX)/bin/aarch64-elf-objcopy

SRC_DIR    := $(DIR)/src
OUTPUT_DIR := $(DIR)/output

# Diagnostic build variant. `scripts/build --debug` sets DEBUG=1, which
# compiles with -DSOREN_DEBUG (019-probe-engine.c switches on and
# #includes the generated probe list, and any --debug-only extra logging
# is compiled in) and uses a SEPARATE object dir, so a debug build and a
# lean build never reuse each other's objects — they were compiled with
# different -D flags. A normal build defines nothing and produces a
# probe-free production image. (--probes is a deprecated alias for
# --debug; see issue 110n.)
# tmp/ in the project root is a symlink into /tmp, and the system
# clears /tmp on every reboot — so the link outlives its target, and
# the first build after any restart finds it dangling. `mkdir -p` on a
# path that runs through a dangling symlink cannot repair that: the
# symlink itself exists, so mkdir stops at "File exists" without ever
# following it, and every object-file directory below fails with it.
# Resolving to the real path once here, and hanging the work
# directories off that, is what lets the recipes' own `mkdir -p` bring
# the whole tree back by itself.
TMP_REAL := $(shell readlink -f $(DIR)/tmp)
ifeq ($(TMP_REAL),)
$(error cannot resolve $(DIR)/tmp — the project expects tmp/ to be a symlink to its RAM-backed work directory)
endif

GEN_DIR := $(TMP_REAL)/build/generated
ifeq ($(DEBUG),1)
BUILD_DIR := $(TMP_REAL)/build/kernel-debug
else
BUILD_DIR := $(TMP_REAL)/build/kernel
endif

LINKER_SCRIPT := $(SRC_DIR)/kernel.ld

# Bare-metal aarch64 flags: freestanding (no libc), no startup files,
# warnings on, optimization on, target the chip explicitly. -fno-builtin
# stops GCC from assuming standard library functions exist.
# -mgeneral-regs-only stops GCC from emitting any instruction that
# touches the chip's 128-bit-wide floating-point and SIMD register
# file; the kernel does not enable that hardware unit, so any
# instruction that touched it would trap before executing. See
# issue 103f for the wider context and the eventual re-enable path
# under soramech.
CFLAGS := -ffreestanding -nostdlib -nostartfiles \
          -Wall -Wextra -O2 \
          -mcpu=cortex-a55 \
          -fno-builtin \
          -mgeneral-regs-only

# Under --debug, switch on the probe engine (and any --debug-only extra
# logging) and add the generated fragment's directory to the include path
# so 019-probe-engine.c can #include "probe-list.inc".
ifeq ($(DEBUG),1)
CFLAGS += -DSOREN_DEBUG -I$(GEN_DIR)
endif

# --no-warn-rwx-segments silences a linker warning that fires on every
# build because our flat-no-MMU kernel collapses text and data into a
# single read-write-execute LOAD segment. The warning is intended for
# hosted programs that benefit from separating code and data into
# distinct memory regions; for a freestanding kernel without
# protection it is informational and not actionable.
LDFLAGS := -T $(LINKER_SCRIPT) -nostdlib --no-warn-rwx-segments

C_SRCS := $(shell find $(SRC_DIR) -name '*.c' 2>/dev/null)
S_SRCS := $(shell find $(SRC_DIR) -name '*.s' 2>/dev/null)
OBJS := $(patsubst $(SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(C_SRCS)) \
        $(patsubst $(SRC_DIR)/%.s,$(BUILD_DIR)/%.o,$(S_SRCS))

# Under --debug, the probe engine #includes the generated probe list.
# Make cannot see an #include, so name the dependency explicitly and
# give a rule that (re)generates the fragment whenever a probe file or
# the generator itself changes — keeping a direct `make DEBUG=1`
# correct without relying on scripts/build to pre-generate.
ifeq ($(DEBUG),1)
PROBE_SRCS := $(wildcard $(DIR)/input/probes/*.probe)
$(GEN_DIR)/probe-list.inc: $(PROBE_SRCS) $(DIR)/scripts/embed-probes
	@mkdir -p $(GEN_DIR)
	@$(DIR)/scripts/embed-probes $(DIR)
$(BUILD_DIR)/019-probe-engine.o: $(GEN_DIR)/probe-list.inc
endif

KERNEL_ELF := $(BUILD_DIR)/kernel.elf
KERNEL_IMG := $(OUTPUT_DIR)/kernel.img

.PHONY: all clean check-toolchain FORCE

all: $(KERNEL_IMG)

check-toolchain:
	@test -x $(CC) || { \
	    echo "ERROR: $(CC) not found. Run scripts/build-deps first." >&2; \
	    exit 1; \
	}

# output/kernel.img holds whichever variant you built last — lean or
# --probes. Both variants objcopy into this one path from their own
# per-variant ELF, so the copy must run on EVERY invocation: otherwise,
# switching variants can leave a newer image of the OTHER variant in
# place and make would skip the copy (a lean build silently shipping the
# probe kernel, or vice versa). FORCE makes the cheap objcopy always run;
# the ELF itself still only relinks when its objects actually change.
$(KERNEL_IMG): $(KERNEL_ELF) FORCE | $(OUTPUT_DIR)
	@$(OBJCOPY) -O binary $< $@
	@echo "image: $@"

FORCE:

$(KERNEL_ELF): $(OBJS) $(LINKER_SCRIPT) | $(BUILD_DIR)
	@echo "linking..."
	@$(LD) $(LDFLAGS) $(OBJS) -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c | check-toolchain
	@mkdir -p $(dir $@)
	@echo "compiling $(notdir $<)..."
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.s | check-toolchain
	@mkdir -p $(dir $@)
	@echo "assembling $(notdir $<)..."
	@$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR) $(OUTPUT_DIR):
	@mkdir -p $@

clean:
	@rm -rf $(BUILD_DIR) $(KERNEL_IMG) $(KERNEL_ELF)
	@echo "cleaned"
