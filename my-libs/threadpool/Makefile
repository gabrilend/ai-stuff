# Threadpool Library Makefile
#
# Builds the core threadpool library and runs tests.
#
# Usage:
#   make          - Build library object file
#   make test     - Build and run tests
#   make clean    - Remove build artifacts

CC = gcc
CFLAGS = -Wall -Wextra -Werror -std=c11 -pthread -O2 -D_GNU_SOURCE
DEBUG_FLAGS = -g -O0 -DDEBUG

SRC_DIR = src
TEST_DIR = tests
BUILD_DIR = build

# Source files
CORE_SRC = $(SRC_DIR)/threadpool.c
CORE_OBJ = $(BUILD_DIR)/threadpool.o

# Test files
TEST_POOL_SRC = $(TEST_DIR)/test_pool.c
TEST_POOL_BIN = $(BUILD_DIR)/test_pool

# {{{ Default target
.PHONY: all
all: $(CORE_OBJ)
# }}}

# {{{ Build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
# }}}

# {{{ Core library object
$(CORE_OBJ): $(CORE_SRC) $(SRC_DIR)/threadpool.h $(SRC_DIR)/threadpool_config.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $(CORE_SRC) -o $(CORE_OBJ)
# }}}

# {{{ Test binary
$(TEST_POOL_BIN): $(TEST_POOL_SRC) $(CORE_SRC) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(DEBUG_FLAGS) -I$(SRC_DIR) $(TEST_POOL_SRC) $(CORE_SRC) -o $(TEST_POOL_BIN)
# }}}

# {{{ Run tests
.PHONY: test
test: $(TEST_POOL_BIN)
	@echo ""
	@echo "Running tests..."
	@echo ""
	@./$(TEST_POOL_BIN)
# }}}

# {{{ Debug build
.PHONY: debug
debug: CFLAGS += $(DEBUG_FLAGS)
debug: $(CORE_OBJ)
# }}}

# {{{ Clean
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
# }}}

# {{{ Help
.PHONY: help
help:
	@echo "Threadpool Library Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all     - Build library object file (default)"
	@echo "  test    - Build and run tests"
	@echo "  debug   - Build with debug symbols"
	@echo "  clean   - Remove build artifacts"
	@echo "  help    - Show this help"
# }}}
