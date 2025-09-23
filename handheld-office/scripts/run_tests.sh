#!/bin/bash
# Handheld Office Test Execution Script
# Usage: ./scripts/run_tests.sh [quick|full|critical|performance|coverage]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if cargo command exists
check_cargo() {
    if ! command -v cargo &> /dev/null; then
        print_error "Cargo not found. Please install Rust and Cargo."
        exit 1
    fi
}

# Function to install required tools
install_tools() {
    print_status "Checking and installing required tools..."
    
    # Check for tarpaulin (coverage)
    if ! cargo tarpaulin --version &> /dev/null; then
        print_status "Installing cargo-tarpaulin for coverage reports..."
        cargo install cargo-tarpaulin
    fi
    
    # Check for criterion (already in dev-dependencies)
    print_success "All required tools are available"
}

# Function to run quick tests
run_quick_tests() {
    print_status "Running quick test suite (< 5 minutes)..."
    
    print_status "1. Format check..."
    cargo fmt --all -- --check || {
        print_warning "Code formatting issues found. Run 'cargo fmt' to fix."
    }
    
    print_status "2. Clippy linting..."
    cargo clippy --all-targets --no-default-features || {
        print_warning "Clippy warnings found. Consider fixing for better code quality."
    }
    
    print_status "3. Core unit tests..."
    cargo test --no-default-features --lib || {
        print_error "Core unit tests failed"
        return 1
    }
    
    print_success "Quick tests completed successfully!"
}

# Function to run critical tests only
run_critical_tests() {
    print_status "Running critical tests only..."
    
    print_status "1. Core functionality tests..."
    cargo test --no-default-features --lib || {
        print_error "Core unit tests failed"
        return 1
    }
    
    print_status "2. Integration tests..."
    cargo test --no-default-features --test integration || {
        print_error "Integration tests failed"
        return 1
    }
    
    print_status "3. Security and stability tests..."
    cargo test --no-default-features security_ stability_ || {
        print_warning "Some security/stability tests failed"
    }
    
    print_success "Critical tests completed!"
}

# Function to run full test suite
run_full_tests() {
    print_status "Running full test suite (15-30 minutes)..."
    
    print_status "1. All unit tests..."
    cargo test --no-default-features --lib || {
        print_error "Unit tests failed"
        return 1
    }
    
    print_status "2. All integration tests..."
    cargo test --no-default-features --tests || {
        print_error "Integration tests failed"
        return 1
    }
    
    print_status "3. Documentation tests..."
    cargo test --no-default-features --doc || {
        print_warning "Documentation tests failed"
    }
    
    print_status "4. Example tests..."
    cargo test --no-default-features --examples || {
        print_warning "Example tests failed"
    }
    
    print_success "Full test suite completed!"
}

# Function to run performance tests
run_performance_tests() {
    print_status "Running performance benchmarks..."
    
    print_status "1. Paint performance benchmarks..."
    cargo bench paint_performance || {
        print_warning "Paint benchmarks had issues"
    }
    
    print_status "2. Music performance benchmarks..."
    cargo bench music_performance || {
        print_warning "Music benchmarks had issues"
    }
    
    print_status "3. Terminal performance benchmarks..."
    cargo bench terminal_performance || {
        print_warning "Terminal benchmarks had issues"
    }
    
    print_status "4. Memory stress tests..."
    cargo bench memory_stress || {
        print_warning "Memory stress tests had issues"
    }
    
    print_success "Performance tests completed! Check target/criterion/report/index.html for detailed results."
}

# Function to run coverage analysis
run_coverage() {
    print_status "Generating code coverage report..."
    
    # Clean previous coverage data
    rm -rf coverage/
    mkdir -p coverage/
    
    print_status "Running tests with coverage analysis..."
    cargo tarpaulin --out Html --output-dir coverage --timeout 300 || {
        print_error "Coverage analysis failed"
        return 1
    }
    
    print_success "Coverage report generated! Open coverage/tarpaulin-report.html to view results."
    
    # Try to open coverage report automatically
    if command -v xdg-open &> /dev/null; then
        xdg-open coverage/tarpaulin-report.html &
    elif command -v open &> /dev/null; then
        open coverage/tarpaulin-report.html &
    else
        print_status "Open coverage/tarpaulin-report.html in your browser to view the report."
    fi
}

# Function to run stress tests
run_stress_tests() {
    print_status "Running stress tests (may take a while)..."
    
    print_status "1. Memory stress tests..."
    cargo test --no-default-features --release memory_stress --ignored || {
        print_warning "Memory stress tests had issues"
    }
    
    print_status "2. Performance stress tests..."
    cargo test --no-default-features --release performance_stress --ignored || {
        print_warning "Performance stress tests had issues"
    }
    
    print_status "3. Long-running stability tests..."
    cargo test --no-default-features --release stability_ --ignored || {
        print_warning "Stability tests had issues"
    }
    
    print_success "Stress tests completed!"
}

# Function to show usage
show_usage() {
    echo "Handheld Office Test Runner"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  quick       Run quick tests (format, clippy, core units) - ~3 minutes"
    echo "  critical    Run critical tests only - ~10 minutes"
    echo "  full        Run complete test suite - ~20 minutes"
    echo "  performance Run performance benchmarks - ~15 minutes"
    echo "  coverage    Generate code coverage report - ~10 minutes"
    echo "  stress      Run stress and stability tests - ~30 minutes"
    echo "  all         Run everything (full + performance + coverage) - ~45 minutes"
    echo ""
    echo "Examples:"
    echo "  $0 quick           # Pre-commit checks"
    echo "  $0 critical        # CI critical path"
    echo "  $0 full            # Complete validation"
    echo "  $0 coverage        # Coverage analysis"
    echo ""
}

# Function to run all tests
run_all_tests() {
    print_status "Running complete test suite with all components..."
    
    local start_time=$(date +%s)
    
    run_full_tests || return 1
    run_performance_tests
    run_coverage || return 1
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    print_success "All tests completed in ${duration} seconds!"
    print_status "Results:"
    print_status "  - Test results: Check console output above"
    print_status "  - Performance: target/criterion/report/index.html"
    print_status "  - Coverage: coverage/tarpaulin-report.html"
}

# Main execution
main() {
    print_status "Handheld Office Test Runner"
    print_status "Working directory: $(pwd)"
    print_status "Timestamp: $(date)"
    echo ""
    
    check_cargo
    
    case "${1:-quick}" in
        "quick")
            install_tools
            run_quick_tests
            ;;
        "critical")
            install_tools
            run_critical_tests
            ;;
        "full")
            install_tools
            run_full_tests
            ;;
        "performance")
            install_tools
            run_performance_tests
            ;;
        "coverage")
            install_tools
            run_coverage
            ;;
        "stress")
            install_tools
            run_stress_tests
            ;;
        "all")
            install_tools
            run_all_tests
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"