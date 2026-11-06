# Threadpool Library Makefile
#
# Builds the library as one static archive and runs the test suite.
# Link with -lthreadpool -pthread; the linker pulls in only the modules a
# program uses, so a program that never calls the scheduler need not define
# g_current_tick.
#
# Usage:
#   make            - Build build/libthreadpool.a (core, sync, updater, scheduler)
#   make test       - Build and run tests
#   make sanitize   - Run tests under ThreadSanitizer and AddressSanitizer
#   make debug      - Build the archive with debug symbols
#   make clean      - Remove build artifacts

CC = gcc
CFLAGS = -Wall -Wextra -Werror -std=c11 -pthread -O2 -D_GNU_SOURCE
DEBUG_FLAGS = -g -O0 -DDEBUG

SRC_DIR = src
TEST_DIR = tests
BUILD_DIR = build

# Source files
MODULES = threadpool threadpool_sync threadpool_updater threadpool_scheduler
OBJS = $(addprefix $(BUILD_DIR)/,$(addsuffix .o,$(MODULES)))
HEADERS = $(wildcard $(SRC_DIR)/*.h)
LIB = $(BUILD_DIR)/libthreadpool.a

# {{{ Default target
.PHONY: all
all: $(LIB)
# }}}

# {{{ Build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
# }}}

# {{{ Module objects and archive
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c $(HEADERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(LIB): $(OBJS)
	rm -f $@
	ar rcs $@ $(OBJS)
# }}}

# {{{ Run tests
.PHONY: test
test:
	$(MAKE) -C $(TEST_DIR) test CC=$(CC)

.PHONY: sanitize
sanitize:
	$(MAKE) -C $(TEST_DIR) sanitize CC=$(CC)
# }}}

# {{{ Debug build
.PHONY: debug
debug: CFLAGS += $(DEBUG_FLAGS)
debug: $(LIB)
# }}}

# {{{ Clean
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
	$(MAKE) -C $(TEST_DIR) clean
# }}}

# {{{ Help
.PHONY: help
help:
	@echo "Threadpool Library Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Build build/libthreadpool.a (default)"
	@echo "  test     - Build and run tests"
	@echo "  sanitize - Run tests under ThreadSanitizer and AddressSanitizer"
	@echo "  debug    - Build with debug symbols"
	@echo "  clean    - Remove build artifacts"
	@echo "  help     - Show this help"
# }}}
