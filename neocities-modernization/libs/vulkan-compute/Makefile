# Makefile for Vulkan Compute Library
# Compiles GLSL compute shaders to SPIR-V and builds the C library

# {{{ Directory paths
DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
SRC_DIR := $(DIR)/src
SHADER_DIR := $(DIR)/shaders
BUILD_DIR := $(DIR)/build
INCLUDE_DIR := $(DIR)/include
# }}}

# {{{ Compiler settings
CC := gcc
CFLAGS := -Wall -Wextra -O2 -I$(INCLUDE_DIR) -fPIC
LDFLAGS := -lvulkan
GLSLC := glslangValidator
# }}}

# {{{ Source and target files
C_SOURCES := $(SRC_DIR)/vk_compute.c $(SRC_DIR)/vk_diversity.c
C_OBJECTS := $(patsubst $(SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(C_SOURCES))
SHADER_SOURCES := $(wildcard $(SHADER_DIR)/*.comp)
SHADER_SPIRV := $(patsubst $(SHADER_DIR)/%.comp,$(BUILD_DIR)/%.spv,$(SHADER_SOURCES))
# }}}

# {{{ Build targets
.PHONY: all clean shaders library shared test

all: shaders library shared

# Compile GLSL shaders to SPIR-V
shaders: $(SHADER_SPIRV)

$(BUILD_DIR)/%.spv: $(SHADER_DIR)/%.comp
	@mkdir -p $(BUILD_DIR)
	$(GLSLC) -V $< -o $@
	@echo "Compiled shader: $< -> $@"

# Build static library
library: $(BUILD_DIR)/libvkcompute.a

$(BUILD_DIR)/libvkcompute.a: $(C_OBJECTS)
	ar rcs $@ $^
	@echo "Built library: $@"

# Build shared library target
shared: $(BUILD_DIR)/libvkcompute.so

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Build shared library (for dynamic linking)
$(BUILD_DIR)/libvkcompute.so: $(C_OBJECTS)
	$(CC) -shared $(C_OBJECTS) $(LDFLAGS) -o $@
	@echo "Built shared library: $@"

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)/*.o $(BUILD_DIR)/*.a $(BUILD_DIR)/*.so $(BUILD_DIR)/*.spv
	@echo "Cleaned build directory"
# }}}

# {{{ Install targets
install: all
	@echo "Installing Vulkan compute library..."
	@mkdir -p /usr/local/lib
	@mkdir -p /usr/local/include
	@cp $(BUILD_DIR)/libvkcompute.a /usr/local/lib/
	@cp $(INCLUDE_DIR)/vk_compute.h /usr/local/include/
	@echo "Installed to /usr/local"
# }}}
