# GBA Ocarina of Time Demake Makefile

# Project name
PROJECT = oot_demake_gba

# Toolchain setup
TOOLCHAIN_PATH = ../tools/gba-toolchain/gcc-arm-none-eabi-10.3-2021.10/bin
CC = $(TOOLCHAIN_PATH)/arm-none-eabi-gcc
AS = $(TOOLCHAIN_PATH)/arm-none-eabi-as
LD = $(TOOLCHAIN_PATH)/arm-none-eabi-ld
OBJCOPY = $(TOOLCHAIN_PATH)/arm-none-eabi-objcopy
OBJDUMP = $(TOOLCHAIN_PATH)/arm-none-eabi-objdump

# Compiler flags
CFLAGS = -mthumb-interwork -mlong-calls -mcpu=arm7tdmi -mtune=arm7tdmi
CFLAGS += -O2 -Wall -Wextra -ffunction-sections -fdata-sections
CFLAGS += -std=c99

# Assembler flags
ASFLAGS = -mcpu=arm7tdmi

# Linker flags
LDFLAGS = -T gba.ld -nostartfiles -Wl,--gc-sections

# Source files
C_SOURCES = main.c input.c background.c sprite.c input_test.c
ASM_SOURCES = crt0.s

# Object files
C_OBJECTS = $(C_SOURCES:.c=.o)
ASM_OBJECTS = $(ASM_SOURCES:.s=.o)
OBJECTS = $(ASM_OBJECTS) $(C_OBJECTS)

# Output files
ELF = $(PROJECT).elf
ROM = $(PROJECT).gba

# Default target
all: $(ROM)

# Build ROM from ELF
$(ROM): $(ELF)
	$(OBJCOPY) -O binary $< $@
	@echo "ROM built: $@"
	@echo "Size: `wc -c < $@` bytes"

# Build ELF from objects
$(ELF): $(OBJECTS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

# Compile C sources
%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Assemble assembly sources
%.o: %.s
	$(AS) $(ASFLAGS) -o $@ $<

# Clean build files
clean:
	rm -f $(OBJECTS) $(ELF) $(ROM)

# Show disassembly
disasm: $(ELF)
	$(OBJDUMP) -D $< > $(PROJECT).s

# Show memory usage
size: $(ELF)
	$(TOOLCHAIN_PATH)/arm-none-eabi-size $<

# Test build (just compile, don't link)
test:
	$(CC) $(CFLAGS) -c $(C_SOURCES)
	$(AS) $(ASFLAGS) -c $(ASM_SOURCES)
	@echo "Test compilation successful"
	rm -f *.o

# Dependencies
main.o: main.c gba_hardware.h input.h background.h sprite.h input_test.h
input.o: input.c gba_hardware.h input.h
background.o: background.c gba_hardware.h background.h input.h
sprite.o: sprite.c gba_hardware.h sprite.h input.h background.h
input_test.o: input_test.c gba_hardware.h input_test.h input.h sprite.h
crt0.o: crt0.s

.PHONY: all clean disasm size test