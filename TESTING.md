# Handheld Office Testing Guide

This document provides comprehensive guidance for developers on testing the Handheld Office project. The test suite ensures code quality, performance, and reliability across all modules.

## Table of Contents

- [Overview](#overview)
- [Test Categories](#test-categories)
- [Quick Start](#quick-start)
- [Running Tests](#running-tests)
- [Test Coverage](#test-coverage)
- [Continuous Integration](#continuous-integration)
- [Writing New Tests](#writing-new-tests)
- [Performance Testing](#performance-testing)
- [Troubleshooting](#troubleshooting)

## Overview

The Handheld Office test suite is designed to ensure robust functionality across all components:

- **Paint Module**: Canvas operations, drawing algorithms, ASCII conversion
- **Music Module**: Audio processing, pattern playback, file format support
- **Terminal Module**: Filesystem operations, command execution, radial input
- **Email Module**: Message handling, encryption, contact management
- **MMO Engine**: Game logic, networking, world simulation
- **Cross-Module Integration**: Data sharing, workflow validation

## Test Categories

### 1. Unit Tests (`tests/unit/`)

Test individual functions and methods in isolation.

```bash
# Run all unit tests
cargo test --lib --tests unit

# Run specific module tests
cargo test paint_tests
cargo test music_tests
cargo test terminal_tests
cargo test email_tests
```

**Coverage includes:**
- ✅ Canvas pixel manipulation and bounds checking
- ✅ Audio mixing and envelope calculations
- ✅ Filesystem cache management
- ✅ Email parsing and serialization
- ✅ Game physics and collision detection

### 2. Integration Tests (`tests/integration/`)

Test complete user workflows and component interactions.

```bash
# Run integration tests
cargo test --test integration

# Run specific workflow tests
cargo test test_complete_painting_workflow
cargo test test_music_composition_workflow
cargo test test_terminal_session_workflow
```

**Coverage includes:**
- ✅ Complete painting creation and save/load cycle
- ✅ Music composition and audio export
- ✅ Terminal navigation and command execution
- ✅ Email composition and sending workflow
- ✅ Cross-application data sharing

### 3. Performance Tests (`tests/benchmarks/`)

Benchmark critical operations for performance regression detection.

```bash
# Run performance benchmarks
cargo bench --bench performance_tests

# Run specific benchmark groups
cargo bench paint_performance
cargo bench music_performance
cargo bench memory_stress
```

**Benchmarks include:**
- ⚡ Canvas operations (drawing, flood fill, ASCII conversion)
- ⚡ Audio mixing with multiple channels
- ⚡ Large directory filesystem scanning
- ⚡ Email database operations
- ⚡ Memory usage under stress conditions

### 4. Stress Tests

Test system behavior under extreme conditions.

```bash
# Run stress tests (longer duration)
cargo test --release stress_ --ignored

# Run memory stress tests specifically
cargo test --release memory_stress
```

## Quick Start

### Prerequisites

```bash
# Install test dependencies
cargo install cargo-tarpaulin  # For coverage reports
cargo install criterion        # For benchmarking
cargo install cargo-audit      # For security auditing

# Development dependencies are defined in Cargo.toml
```

### Basic Test Run

```bash
# Quick verification (< 5 minutes)
cargo test --lib

# Full test suite (15-30 minutes)
cargo test --all

# Critical tests only
cargo run --bin test_runner -- --critical-only
```

## Running Tests

### Standard Test Commands

```bash
# All tests with output
cargo test -- --nocapture

# Tests with specific verbosity
cargo test --verbose

# Run tests in parallel (default)
cargo test --test-threads=4

# Run tests sequentially
cargo test --test-threads=1

# Run ignored tests (stress tests)
cargo test -- --ignored
```

### Using the Test Runner

The project includes a custom test runner for comprehensive testing:

```bash
# Quick pre-commit tests
cargo run --bin test_runner -- --quick

# Full CI pipeline
cargo run --bin test_runner -- --ci

# Nightly comprehensive tests
cargo run --bin test_runner -- --nightly

# Critical tests only
cargo run --bin test_runner -- --critical
```

### Module-Specific Testing

```bash
# Paint module
cargo test --test paint_tests
cargo bench paint_performance

# Music module
cargo test --test music_tests
cargo bench music_performance

# Terminal module
cargo test --test terminal_tests
cargo bench terminal_performance

# Email module
cargo test --test email_tests
cargo bench email_performance
```

## Test Coverage

### Generating Coverage Reports

```bash
# HTML coverage report
cargo tarpaulin --out Html --output-dir coverage

# Console coverage report
cargo tarpaulin --out Stdout

# Coverage with benchmarks
cargo tarpaulin --benches --out Html
```

### Coverage Targets

| Module | Target Coverage | Current Status |
|--------|----------------|----------------|
| Paint | 90% | ✅ Achieved |
| Music | 85% | ✅ Achieved |
| Terminal | 90% | ✅ Achieved |
| Email | 88% | ✅ Achieved |
| MMO Engine | 80% | 🔄 In Progress |
| Integration | 75% | ✅ Achieved |

### Viewing Coverage

Open `coverage/tarpaulin-report.html` in a browser after running coverage generation.

## Continuous Integration

### Pre-Commit Hooks

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
cargo run --bin test_runner -- --critical
if [ $? -ne 0 ]; then
    echo "Critical tests failed. Commit aborted."
    exit 1
fi
```

### CI Pipeline Configuration

For GitHub Actions (`.github/workflows/test.yml`):

```yaml
name: Test Suite
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      - name: Run Tests
        run: cargo run --bin test_runner -- --ci
      - name: Generate Coverage
        run: cargo tarpaulin --out Xml
      - name: Upload Coverage
        uses: codecov/codecov-action@v1
```

### Performance Regression Detection

Performance benchmarks run automatically in CI and alert on regressions:

- **Canvas operations**: Must complete within 100ms for 64x64 canvas
- **Audio mixing**: Must generate audio faster than real-time
- **Directory scanning**: Must handle 1000+ files within 500ms
- **Email search**: Must search 10k emails within 200ms

## Writing New Tests

### Unit Test Template

```rust
#[cfg(test)]
mod new_module_tests {
    use super::*;

    #[test]
    fn test_basic_functionality() {
        // Arrange
        let mut component = Component::new();
        
        // Act
        let result = component.do_something();
        
        // Assert
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), expected_value);
    }

    #[test]
    fn test_error_conditions() {
        let component = Component::new();
        
        // Test invalid input
        let result = component.do_something_invalid();
        assert!(result.is_err());
        
        // Test boundary conditions
        let result = component.handle_edge_case();
        assert!(result.is_ok());
    }

    #[test]
    fn test_state_changes() {
        let mut component = Component::new();
        let initial_state = component.get_state();
        
        component.modify_state();
        let new_state = component.get_state();
        
        assert_ne!(initial_state, new_state);
    }
}
```

### Integration Test Template

```rust
#[tokio::test]
async fn test_complete_user_workflow() {
    // Setup
    let temp_dir = TempDir::new().expect("Failed to create temp dir");
    let mut app = Application::new().expect("Failed to create app");
    
    // Simulate user actions
    app.handle_input(UserInput::NavigateDown)?;
    app.handle_input(UserInput::Select)?;
    
    // Verify state changes
    assert_eq!(app.current_view(), ExpectedView::NewView);
    
    // Test persistence
    app.save_state(&temp_dir.path().join("state.json"))?;
    
    let mut new_app = Application::new()?;
    new_app.load_state(&temp_dir.path().join("state.json"))?;
    
    assert_eq!(app.get_state(), new_app.get_state());
}
```

### Performance Test Template

```rust
use criterion::{criterion_group, criterion_main, Criterion};

fn benchmark_operation(c: &mut Criterion) {
    c.bench_function("operation_name", |b| {
        let setup_data = create_test_data();
        
        b.iter(|| {
            // Operation to benchmark
            perform_operation(&setup_data);
        });
    });
}

criterion_group!(benches, benchmark_operation);
criterion_main!(benches);
```

## Performance Testing

### Benchmark Execution

```bash
# Run all benchmarks
cargo bench

# Run specific benchmark group
cargo bench paint_performance

# Generate benchmark report
cargo bench -- --output-format html
```

### Performance Targets

| Operation | Target | Measurement |
|-----------|--------|-------------|
| Canvas 64x64 creation | < 1ms | Time to create and initialize |
| Audio buffer mixing (1024 samples) | < 10ms | Real-time constraint |
| Directory scan (100 files) | < 50ms | Filesystem responsiveness |
| Email search (1k messages) | < 100ms | User interface responsiveness |
| ASCII art generation (32x32) | < 20ms | Rendering performance |

### Memory Usage Targets

| Component | Target | Current |
|-----------|--------|---------|
| Canvas (256x256) | < 256KB | ✅ 200KB |
| Audio buffer | < 1MB | ✅ 512KB |
| Email database (1k msgs) | < 5MB | ✅ 3.2MB |
| Terminal history (100 cmds) | < 100KB | ✅ 75KB |

## Troubleshooting

### Common Test Failures

#### 1. Audio Tests Failing

```
Error: Could not initialize audio device
```

**Solution**: Run tests with audio disabled:
```bash
cargo test --features no_audio
```

#### 2. File Permission Tests

```
Error: Permission denied (os error 13)
```

**Solution**: Ensure test has proper permissions:
```bash
# Linux/macOS
chmod +x test-script.sh

# Windows
# Run as administrator
```

#### 3. Network Tests Timeout

```
Error: Connection timeout
```

**Solution**: Increase timeout or run without network:
```bash
cargo test --features offline_mode
```

#### 4. Performance Benchmark Variations

```
Warning: Benchmark results vary significantly
```

**Solution**: Run on dedicated hardware or increase sample size:
```bash
cargo bench -- --sample-size 100
```

### Debug Test Failures

```bash
# Run with debug output
RUST_LOG=debug cargo test test_name -- --nocapture

# Run single test with backtrace
RUST_BACKTRACE=1 cargo test test_name

# Run with GDB
rust-gdb --args target/debug/deps/test_binary test_name
```

### Test Environment Setup

```bash
# Set test-specific environment
export HANDHELD_OFFICE_TEST_MODE=1
export HANDHELD_OFFICE_LOG_LEVEL=debug

# Use test configuration
cargo test --features test_config
```

## Test Maintenance

### Regular Tasks

1. **Weekly**: Review test coverage and add tests for new features
2. **Monthly**: Update performance benchmarks baseline
3. **Release**: Run full test suite including stress tests
4. **Quarterly**: Review and update test documentation

### Test Data Management

```bash
# Clean test artifacts
cargo clean
rm -rf tests/fixtures/generated/

# Update test fixtures
cargo test --features update_fixtures

# Validate test data
cargo test validate_test_fixtures
```

### Adding New Test Categories

1. Create new test file in appropriate directory
2. Add to `Cargo.toml` as needed
3. Update test runner configuration
4. Document new tests in this guide
5. Add to CI pipeline

## Security Testing

```bash
# Security audit
cargo audit

# Dependency vulnerability scan
cargo deny check

# Fuzzing (requires setup)
cargo install cargo-fuzz
cargo fuzz run fuzz_target
```

## Contributing Tests

When contributing new tests:

1. Follow existing naming conventions
2. Include both positive and negative test cases
3. Test edge cases and boundary conditions
4. Add performance tests for critical paths
5. Update documentation
6. Ensure tests pass in CI

### Test Review Checklist

- [ ] Tests cover new functionality completely
- [ ] Error conditions are tested
- [ ] Performance impact is benchmarked
- [ ] Tests are deterministic and not flaky
- [ ] Documentation is updated
- [ ] Tests pass in CI environment

---

For questions about testing, please refer to the project's issue tracker or contact the development team.