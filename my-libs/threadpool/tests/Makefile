# Threadpool Test Suite Makefile

CC = gcc
CFLAGS = -Wall -Wextra -pthread -I../src -g -O0
LDFLAGS = -pthread

# Source directories
SRC_DIR = ../src
BUILD_DIR = build

# Core module sources
CORE_SRCS = $(SRC_DIR)/threadpool.c
CORE_OBJS = $(BUILD_DIR)/threadpool.o

# Sync module sources
SYNC_SRCS = $(SRC_DIR)/threadpool_sync.c
SYNC_OBJS = $(BUILD_DIR)/threadpool_sync.o

# Updater module sources
UPDATER_SRCS = $(SRC_DIR)/threadpool_updater.c
UPDATER_OBJS = $(BUILD_DIR)/threadpool_updater.o

# Scheduler module sources
SCHEDULER_SRCS = $(SRC_DIR)/threadpool_scheduler.c
SCHEDULER_OBJS = $(BUILD_DIR)/threadpool_scheduler.o

# Test executables
TESTS = test_pool test_sync test_updater test_scheduler

.PHONY: all clean run test

all: $(BUILD_DIR) $(TESTS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile core module
$(CORE_OBJS): $(CORE_SRCS)
	$(CC) $(CFLAGS) -c $(CORE_SRCS) -o $(CORE_OBJS)

# Compile sync module
$(SYNC_OBJS): $(SYNC_SRCS)
	$(CC) $(CFLAGS) -c $(SYNC_SRCS) -o $(SYNC_OBJS)

# Compile updater module
$(UPDATER_OBJS): $(UPDATER_SRCS)
	$(CC) $(CFLAGS) -c $(UPDATER_SRCS) -o $(UPDATER_OBJS)

# Compile scheduler module
$(SCHEDULER_OBJS): $(SCHEDULER_SRCS)
	$(CC) $(CFLAGS) -c $(SCHEDULER_SRCS) -o $(SCHEDULER_OBJS)

# Build test_pool (core module only)
test_pool: test_pool.c $(CORE_OBJS)
	$(CC) $(CFLAGS) test_pool.c $(CORE_OBJS) $(LDFLAGS) -o test_pool

# Build test_sync (core + sync modules)
test_sync: test_sync.c $(CORE_OBJS) $(SYNC_OBJS)
	$(CC) $(CFLAGS) test_sync.c $(CORE_OBJS) $(SYNC_OBJS) $(LDFLAGS) -o test_sync

# Build test_updater (core + updater modules)
test_updater: test_updater.c $(CORE_OBJS) $(UPDATER_OBJS)
	$(CC) $(CFLAGS) test_updater.c $(CORE_OBJS) $(UPDATER_OBJS) $(LDFLAGS) -o test_updater

# Build test_scheduler (core + scheduler modules)
test_scheduler: test_scheduler.c $(CORE_OBJS) $(SCHEDULER_OBJS)
	$(CC) $(CFLAGS) test_scheduler.c $(CORE_OBJS) $(SCHEDULER_OBJS) $(LDFLAGS) -o test_scheduler

# Run all tests
run: all
	@echo "==================================================="
	@echo "Running Threadpool Test Suite"
	@echo "==================================================="
	@echo ""
	@./test_pool && echo "" || exit 1
	@./test_sync && echo "" || exit 1
	@./test_updater && echo "" || exit 1
	@./test_scheduler && echo "" || exit 1
	@echo "==================================================="
	@echo "All test suites passed!"
	@echo "==================================================="

# Alias for run
test: run

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -f test_pool test_sync test_updater test_scheduler
	@echo "Cleaned test build artifacts"

# Help target
help:
	@echo "Threadpool Test Suite Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all        - Build all test executables"
	@echo "  run/test   - Build and run all tests"
	@echo "  clean      - Remove build artifacts"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Individual tests:"
	@echo "  test_pool      - Core threadpool tests"
	@echo "  test_sync      - Sync module tests"
	@echo "  test_updater   - Updater module tests"
	@echo "  test_scheduler - Scheduler module tests"
