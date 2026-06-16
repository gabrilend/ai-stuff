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
BUILD_DIR  := $(DIR)/tmp/build/kernel
OUTPUT_DIR := $(DIR)/output

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

KERNEL_ELF := $(BUILD_DIR)/kernel.elf
KERNEL_IMG := $(OUTPUT_DIR)/kernel.img

.PHONY: all clean check-toolchain

all: $(KERNEL_IMG)

check-toolchain:
	@test -x $(CC) || { \
	    echo "ERROR: $(CC) not found. Run scripts/build-deps first." >&2; \
	    exit 1; \
	}

$(KERNEL_IMG): $(KERNEL_ELF) | $(OUTPUT_DIR)
	@$(OBJCOPY) -O binary $< $@
	@echo "image: $@"

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
