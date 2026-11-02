# Threadpool Test Suite Makefile
#
# Builds each test file against only the modules it needs and runs them.
# Binaries go in a build directory, never beside the sources.
#
# Usage:
#   make test      - Build and run all tests
#   make tsan      - Run all tests under ThreadSanitizer (data races)
#   make asan      - Run all tests under AddressSanitizer + UBSan (memory, leaks)
#   make sanitize  - Both of the above
#   make CC=clang test  - Any of these with clang instead of gcc
#   make clean     - Remove build artifacts

CC = gcc
SAN_FLAGS ?=
CFLAGS = -Wall -Wextra -Werror -std=c11 -D_GNU_SOURCE -pthread -I../src -g -O1 $(SAN_FLAGS)
LDFLAGS = -pthread $(SAN_FLAGS)

SRC_DIR = ../src
BUILD_DIR ?= build

HEADERS = $(wildcard $(SRC_DIR)/*.h) test_common.h

CORE_SRCS = $(SRC_DIR)/threadpool.c
SYNC_SRCS = $(SRC_DIR)/threadpool_sync.c
UPDATER_SRCS = $(SRC_DIR)/threadpool_updater.c
SCHEDULER_SRCS = $(SRC_DIR)/threadpool_scheduler.c

TESTS = test_pool test_sync test_updater test_scheduler
TEST_BINS = $(addprefix $(BUILD_DIR)/,$(TESTS))

.PHONY: all run test tsan asan sanitize clean help

# {{{ Default target
all: $(TEST_BINS)
# }}}

# {{{ Build directory
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
# }}}

# {{{ Test binaries
# test_pool: core module only
$(BUILD_DIR)/test_pool: test_pool.c $(CORE_SRCS) $(HEADERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) test_pool.c $(CORE_SRCS) $(LDFLAGS) -o $@

# test_sync: sync module only (it does not need the core)
$(BUILD_DIR)/test_sync: test_sync.c $(SYNC_SRCS) $(HEADERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) test_sync.c $(SYNC_SRCS) $(LDFLAGS) -o $@

# test_updater: core + updater modules
$(BUILD_DIR)/test_updater: test_updater.c $(CORE_SRCS) $(UPDATER_SRCS) $(HEADERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) test_updater.c $(CORE_SRCS) $(UPDATER_SRCS) $(LDFLAGS) -o $@

# test_scheduler: core + updater + scheduler (the last test feeds an updater)
$(BUILD_DIR)/test_scheduler: test_scheduler.c $(CORE_SRCS) $(UPDATER_SRCS) $(SCHEDULER_SRCS) $(HEADERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) test_scheduler.c $(CORE_SRCS) $(UPDATER_SRCS) $(SCHEDULER_SRCS) $(LDFLAGS) -o $@
# }}}

# {{{ Run all tests
run: all
	@echo "==================================================="
	@echo "Running Threadpool Test Suite $(if $(SAN_FLAGS),($(SAN_FLAGS)),)"
	@echo "==================================================="
	@echo ""
	@for t in $(TEST_BINS); do ./$$t || exit 1; echo ""; done
	@echo "==================================================="
	@echo "All test suites passed!"
	@echo "==================================================="

# Alias for run
test: run
# }}}

# {{{ Sanitizer runs
# Each sanitizer builds into its own directory, so plain and sanitized
# binaries never mix. halt_on_error makes any report fail the run.
tsan:
	TSAN_OPTIONS="halt_on_error=1 second_deadlock_stack=1" \
	$(MAKE) run BUILD_DIR=build-tsan SAN_FLAGS="-fsanitize=thread"

asan:
	ASAN_OPTIONS="halt_on_error=1 detect_leaks=1" UBSAN_OPTIONS="halt_on_error=1 print_stacktrace=1" \
	$(MAKE) run BUILD_DIR=build-asan SAN_FLAGS="-fsanitize=address,undefined -fno-omit-frame-pointer"

sanitize: tsan asan
# }}}

# {{{ Clean
clean:
	rm -rf build build-tsan build-asan
	@echo "Cleaned test build artifacts"
# }}}

# {{{ Help
help:
	@echo "Threadpool Test Suite Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Build all test executables"
	@echo "  run/test   - Build and run all tests"
	@echo "  tsan       - Run all tests under ThreadSanitizer"
	@echo "  asan       - Run all tests under AddressSanitizer + UBSan"
	@echo "  sanitize   - Run both sanitizer passes"
	@echo "  clean      - Remove build artifacts"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Test files:"
	@echo "  test_pool      - Core threadpool tests"
	@echo "  test_sync      - Sync module tests"
	@echo "  test_updater   - Updater module tests"
	@echo "  test_scheduler - Scheduler module tests"
# }}}
