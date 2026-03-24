# Makefile for HTML Threaded Writer Library
# Compiles pthreads-based parallel file writing library

# {{{ Directory paths
DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
SRC_DIR := $(DIR)/src
BUILD_DIR := $(DIR)/build
INCLUDE_DIR := $(DIR)/include
# }}}

# {{{ Compiler settings
CC := gcc
CFLAGS := -Wall -Wextra -O2 -I$(INCLUDE_DIR) -fPIC
LDFLAGS := -pthread
# }}}

# {{{ Source and target files
C_SOURCES := $(SRC_DIR)/html_gen.c
C_OBJECTS := $(patsubst $(SRC_DIR)/%.c,$(BUILD_DIR)/%.o,$(C_SOURCES))
SHARED_LIB := $(BUILD_DIR)/libhtmlgen.so
STATIC_LIB := $(BUILD_DIR)/libhtmlgen.a
# }}}

# {{{ Build targets
.PHONY: all clean shared static test

all: shared

# Build shared library (primary target for FFI)
shared: $(SHARED_LIB)

$(SHARED_LIB): $(C_OBJECTS)
	@mkdir -p $(BUILD_DIR)
	$(CC) -shared $(C_OBJECTS) $(LDFLAGS) -o $@
	@echo "Built shared library: $@"

# Build static library
static: $(STATIC_LIB)

$(STATIC_LIB): $(C_OBJECTS)
	ar rcs $@ $^
	@echo "Built static library: $@"

# Compile object files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c $(INCLUDE_DIR)/html_gen.h
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory"
# }}}

# {{{ Test target
test: shared
	@echo "Running basic test..."
	@echo "Library built successfully: $(SHARED_LIB)"
	@ls -la $(SHARED_LIB)
	@echo "Checking symbols..."
	@nm -D $(SHARED_LIB) | grep htmlgen
# }}}
