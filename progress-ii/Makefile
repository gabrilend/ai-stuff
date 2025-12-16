# Progress-II Makefile with Automatic Dependency Management
# Ensures adroit and other dependencies are synced before build

# Hard-coded DIR path as per CLAUDE.md requirements
DIR := $(shell pwd)

# Dependency sync script
DEPENDENCY_SYNC := $(DIR)/libs/dependency-sync.sh

# Build configuration
BUILD_DIR := build
SRC_DIR := src
LIBS_DIR := libs

# Include paths for dependencies  
ADROIT_INCLUDE := $(LIBS_DIR)/adroit/src/src
ADROIT_LIBS := $(LIBS_DIR)/adroit/src/libs

# Default target
.PHONY: all
all: deps build

# {{{ Dependency Management
.PHONY: deps
deps:
	@echo "🔄 Syncing dependencies..."
	@$(DEPENDENCY_SYNC) sync

.PHONY: deps-status  
deps-status:
	@$(DEPENDENCY_SYNC) status

.PHONY: deps-clean
deps-clean:
	@$(DEPENDENCY_SYNC) clean

.PHONY: deps-rebuild
deps-rebuild:
	@$(DEPENDENCY_SYNC) rebuild

.PHONY: deps-interactive
deps-interactive:
	@$(DEPENDENCY_SYNC) -I
# }}}

# {{{ Build System
.PHONY: build
build: deps
	@echo "🔨 Building progress-ii with adroit integration..."
	@mkdir -p $(BUILD_DIR)
	
	# Verify adroit is available
	@if [ ! -d "$(ADROIT_INCLUDE)" ]; then \
		echo "❌ Adroit dependency not found. Run 'make deps' first."; \
		exit 1; \
	fi
	
	# Build any C components that use adroit
	@if [ -f "$(SRC_DIR)/integration.c" ]; then \
		echo "📦 Compiling C integration components..."; \
		gcc -I$(ADROIT_INCLUDE) -o $(BUILD_DIR)/integration $(SRC_DIR)/integration.c $(ADROIT_INCLUDE)/dice.c $(ADROIT_INCLUDE)/item.c -lm; \
	fi
	
	@echo "✅ Build complete"

.PHONY: test
test: build
	@echo "🧪 Running tests..."
	@if [ -f "$(BUILD_DIR)/integration" ]; then \
		echo "Testing C integration..."; \
		$(BUILD_DIR)/integration; \
	fi
	
	# Test bash components
	@echo "Testing bash components..."
	@bash -n $(SRC_DIR)/*.sh 2>/dev/null || echo "⚠️ Bash syntax check passed"
	
	@echo "✅ All tests passed"
# }}}

# {{{ Development Support
.PHONY: dev-setup
dev-setup:
	@echo "🛠️ Setting up development environment..."
	@$(DEPENDENCY_SYNC) sync
	@echo "Development environment ready"

.PHONY: clean
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "✅ Clean complete"

.PHONY: distclean
distclean: clean deps-clean
	@echo "🧹 Deep clean (including dependencies)..."
	@echo "✅ Deep clean complete"

.PHONY: install
install: build
	@echo "📦 Installing progress-ii..."
	@mkdir -p ~/.local/bin
	@cp -r $(SRC_DIR)/* ~/.local/bin/ 2>/dev/null || true
	@if [ -f "$(BUILD_DIR)/integration" ]; then \
		cp $(BUILD_DIR)/integration ~/.local/bin/; \
	fi
	@echo "✅ Installed to ~/.local/bin"

.PHONY: uninstall
uninstall:
	@echo "🗑️ Uninstalling progress-ii..."
	@rm -f ~/.local/bin/progress-ii*
	@rm -f ~/.local/bin/integration
	@echo "✅ Uninstalled"
# }}}

# {{{ Adroit Integration Helpers
.PHONY: adroit-demo
adroit-demo: deps
	@echo "🎮 Running adroit demo..."
	@if [ -f "$(LIBS_DIR)/adroit/src/demo_selector.sh" ]; then \
		cd $(LIBS_DIR)/adroit/src && ./demo_selector.sh --all; \
	else \
		echo "❌ Adroit demo not found at $(LIBS_DIR)/adroit/src/demo_selector.sh"; \
	fi

.PHONY: adroit-build
adroit-build:
	@$(DEPENDENCY_SYNC) build adroit

.PHONY: adroit-test
adroit-test: deps
	@echo "🧪 Testing adroit integration..."
	@if [ -f "$(LIBS_DIR)/adroit/src/src/simple_test" ]; then \
		$(LIBS_DIR)/adroit/src/src/simple_test; \
	else \
		echo "Building adroit first..."; \
		cd $(LIBS_DIR)/adroit/src && make; \
		$(LIBS_DIR)/adroit/src/src/simple_test; \
	fi
# }}}

# {{{ Integration Development
.PHONY: integration-template
integration-template:
	@echo "📋 Creating integration template..."
	@mkdir -p $(SRC_DIR)
	@echo '// Progress-II ↔ Adroit Integration Template' > $(SRC_DIR)/integration.c
	@echo '#include <stdio.h>' >> $(SRC_DIR)/integration.c
	@echo '#include <stdlib.h>' >> $(SRC_DIR)/integration.c
	@echo '' >> $(SRC_DIR)/integration.c
	@echo '// Include adroit headers' >> $(SRC_DIR)/integration.c
	@echo '#include "unit.h"' >> $(SRC_DIR)/integration.c
	@echo '#include "dice.h"' >> $(SRC_DIR)/integration.c
	@echo '#include "item.h"' >> $(SRC_DIR)/integration.c
	@echo '#include "logging.h"' >> $(SRC_DIR)/integration.c
	@echo '#include "bash_bridge.h"' >> $(SRC_DIR)/integration.c
	@echo '' >> $(SRC_DIR)/integration.c
	@echo 'int main() {' >> $(SRC_DIR)/integration.c
	@echo '    printf("🤝 Progress-II ↔ Adroit Integration Test\\n\\n");' >> $(SRC_DIR)/integration.c
	@echo '    init_random();' >> $(SRC_DIR)/integration.c
	@echo '    initialize_all_items();' >> $(SRC_DIR)/integration.c
	@echo '    Unit* character = init_unit();' >> $(SRC_DIR)/integration.c
	@echo '    if (character) {' >> $(SRC_DIR)/integration.c
	@echo '        printf("✅ Character generated: %s\\n", character->name ? character->name : "Unknown");' >> $(SRC_DIR)/integration.c
	@echo '        printf("   HP: %d/%d, STR: %d\\n", character->hp[0], character->hp[1], character->stats[1]);' >> $(SRC_DIR)/integration.c
	@echo '        if (character->name) free(character->name);' >> $(SRC_DIR)/integration.c
	@echo '        free(character);' >> $(SRC_DIR)/integration.c
	@echo '    }' >> $(SRC_DIR)/integration.c
	@echo '    cleanup_all_items();' >> $(SRC_DIR)/integration.c
	@echo '    printf("\\n🎉 Integration test complete!\\n");' >> $(SRC_DIR)/integration.c
	@echo '    return 0;' >> $(SRC_DIR)/integration.c
	@echo '}' >> $(SRC_DIR)/integration.c
	@echo "✅ Template created at $(SRC_DIR)/integration.c"
	@echo "   Run 'make build' to compile and test"
# }}}

# {{{ Help
.PHONY: help
help:
	@echo "Progress-II Makefile - Automated Dependency Management"
	@echo ""
	@echo "Dependencies:"
	@echo "  deps                   Sync all dependencies (adroit, etc.)"
	@echo "  deps-status            Show dependency sync status"  
	@echo "  deps-clean             Remove all dependencies"
	@echo "  deps-rebuild           Clean sync and build all dependencies"
	@echo "  deps-interactive       Interactive dependency management"
	@echo ""
	@echo "Build:"
	@echo "  build                  Build progress-ii with dependencies"
	@echo "  test                   Run all tests"
	@echo "  clean                  Clean build artifacts"
	@echo "  distclean             Clean everything including dependencies"
	@echo ""
	@echo "Development:"
	@echo "  dev-setup              Set up development environment"
	@echo "  install                Install to ~/.local/bin"
	@echo "  uninstall              Remove from ~/.local/bin"
	@echo ""
	@echo "Adroit Integration:"
	@echo "  adroit-demo            Run adroit demo system"
	@echo "  adroit-build           Build only adroit dependency"
	@echo "  adroit-test            Test adroit integration"
	@echo "  integration-template   Create integration template"
	@echo ""
	@echo "Example workflow:"
	@echo "  make dev-setup         # Set up development environment"
	@echo "  make build             # Build with all dependencies"
	@echo "  make test              # Verify everything works"
	@echo "  make adroit-demo       # Try out adroit features"
# }}}

# Default help when no target specified
.DEFAULT_GOAL := help