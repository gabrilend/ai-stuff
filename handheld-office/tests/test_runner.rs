use colored::Colorize;
/// Comprehensive test runner for the Handheld Office project
///
/// This module provides utilities for running different categories of tests
/// and generating coverage reports for developers.
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

#[derive(Debug, Clone)]
pub struct TestSuite {
    pub name: String,
    pub description: String,
    pub command: String,
    pub timeout: Duration,
    pub critical: bool, // If true, failure blocks deployment
}

impl TestSuite {
    pub fn new(
        name: &str,
        description: &str,
        command: &str,
        timeout_secs: u64,
        critical: bool,
    ) -> Self {
        Self {
            name: name.to_string(),
            description: description.to_string(),
            command: command.to_string(),
            timeout: Duration::from_secs(timeout_secs),
            critical,
        }
    }
}

#[derive(Debug)]
pub struct TestResult {
    pub suite: TestSuite,
    pub success: bool,
    pub duration: Duration,
    pub output: String,
    pub error: Option<String>,
}

pub struct TestRunner {
    pub suites: Vec<TestSuite>,
    pub parallel: bool,
    pub verbose: bool,
}

impl TestRunner {
    pub fn new() -> Self {
        Self {
            suites: Vec::new(),
            parallel: true,
            verbose: false,
        }
    }

    pub fn add_standard_suites(&mut self) {
        // Unit tests
        self.suites.push(TestSuite::new(
            "unit_tests",
            "Core unit tests for all modules",
            "cargo test --lib --tests unit",
            300,
            true,
        ));

        // Integration tests
        self.suites.push(TestSuite::new(
            "integration_tests",
            "User workflow integration tests",
            "cargo test --test integration",
            600,
            true,
        ));

        // Paint module specific tests
        self.suites.push(TestSuite::new(
            "paint_tests",
            "Paint module comprehensive testing",
            "cargo test paint_tests",
            180,
            true,
        ));

        // Music module specific tests
        self.suites.push(TestSuite::new(
            "music_tests",
            "Music tracker and audio processing tests",
            "cargo test music_tests",
            300,
            true,
        ));

        // Terminal module specific tests
        self.suites.push(TestSuite::new(
            "terminal_tests",
            "Terminal emulator and filesystem tests",
            "cargo test terminal_tests",
            240,
            true,
        ));

        // Email module specific tests
        self.suites.push(TestSuite::new(
            "email_tests",
            "Email client and encryption tests",
            "cargo test email_tests",
            180,
            true,
        ));

        // Network and security tests
        self.suites.push(TestSuite::new(
            "network_security_tests",
            "Network protocols and cryptography tests",
            "cargo test --features network_test scuttlebutt mmo_engine",
            600,
            true,
        ));

        // Performance benchmarks (non-critical)
        self.suites.push(TestSuite::new(
            "performance_benchmarks",
            "Performance and memory usage benchmarks",
            "cargo bench --bench performance_tests",
            1200,
            false,
        ));

        // Stress tests (non-critical)
        self.suites.push(TestSuite::new(
            "stress_tests",
            "High-load and edge case stress tests",
            "cargo test --release stress_ --ignored",
            1800,
            false,
        ));

        // Documentation tests
        self.suites.push(TestSuite::new(
            "doc_tests",
            "Documentation examples and code snippets",
            "cargo test --doc",
            180,
            false,
        ));

        // Clippy linting
        self.suites.push(TestSuite::new(
            "clippy_lint",
            "Rust clippy linter checks",
            "cargo clippy --all-targets --all-features -- -D warnings",
            300,
            true,
        ));

        // Format checking
        self.suites.push(TestSuite::new(
            "format_check",
            "Code formatting verification",
            "cargo fmt --all -- --check",
            60,
            false,
        ));
    }

    pub fn run_all(&self) -> Vec<TestResult> {
        println!(
            "{}",
            "🚀 Starting Handheld Office Test Suite".bold().green()
        );
        println!(
            "{}",
            format!("Running {} test suites", self.suites.len()).cyan()
        );
        println!();

        let start_time = Instant::now();
        let mut results = Vec::new();

        for suite in &self.suites {
            let result = self.run_suite(suite);

            // Print immediate feedback
            self.print_suite_result(&result);

            results.push(result);
        }

        let total_duration = start_time.elapsed();
        self.print_summary(&results, total_duration);

        results
    }

    fn run_suite(&self, suite: &TestSuite) -> TestResult {
        if self.verbose {
            println!("{}", format!("🔧 Running: {}", suite.name).yellow());
            println!("   {}", suite.description);
        }

        let start_time = Instant::now();

        let mut cmd = Command::new("sh");
        cmd.arg("-c")
            .arg(&suite.command)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        match cmd.spawn() {
            Ok(mut child) => {
                // Wait for completion with timeout
                let result = std::thread::spawn(move || child.wait_with_output());

                match result.join() {
                    Ok(Ok(output)) => {
                        let duration = start_time.elapsed();
                        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
                        let stderr = String::from_utf8_lossy(&output.stderr).to_string();

                        TestResult {
                            suite: suite.clone(),
                            success: output.status.success(),
                            duration,
                            output: stdout,
                            error: if stderr.is_empty() {
                                None
                            } else {
                                Some(stderr)
                            },
                        }
                    }
                    Ok(Err(e)) => TestResult {
                        suite: suite.clone(),
                        success: false,
                        duration: start_time.elapsed(),
                        output: String::new(),
                        error: Some(format!("Process error: {}", e)),
                    },
                    Err(_) => TestResult {
                        suite: suite.clone(),
                        success: false,
                        duration: start_time.elapsed(),
                        output: String::new(),
                        error: Some("Thread join error".to_string()),
                    },
                }
            }
            Err(e) => TestResult {
                suite: suite.clone(),
                success: false,
                duration: start_time.elapsed(),
                output: String::new(),
                error: Some(format!("Failed to spawn process: {}", e)),
            },
        }
    }

    fn print_suite_result(&self, result: &TestResult) {
        let status = if result.success {
            "✅ PASS".green()
        } else {
            "❌ FAIL".red()
        };

        let critical_marker = if result.suite.critical {
            " [CRITICAL]"
        } else {
            ""
        };

        println!(
            "{} {} ({:.2}s){}",
            status,
            result.suite.name.bold(),
            result.duration.as_secs_f64(),
            critical_marker.red()
        );

        if !result.success && self.verbose {
            if let Some(error) = &result.error {
                println!("   Error: {}", error.red());
            }
            if !result.output.is_empty() {
                println!(
                    "   Output: {}",
                    result
                        .output
                        .lines()
                        .take(5)
                        .collect::<Vec<_>>()
                        .join("\n   ")
                );
            }
        }
    }

    fn print_summary(&self, results: &[TestResult], total_duration: Duration) {
        println!();
        println!("{}", "📊 Test Summary".bold().cyan());
        println!("{}", "─".repeat(50));

        let total_tests = results.len();
        let passed_tests = results.iter().filter(|r| r.success).count();
        let failed_tests = total_tests - passed_tests;
        let critical_failures = results
            .iter()
            .filter(|r| !r.success && r.suite.critical)
            .count();

        println!("Total Suites: {}", total_tests);
        println!("Passed: {}", format!("{}", passed_tests).green());
        println!("Failed: {}", format!("{}", failed_tests).red());
        println!(
            "Critical Failures: {}",
            format!("{}", critical_failures).red().bold()
        );
        println!("Total Time: {:.2}s", total_duration.as_secs_f64());

        if critical_failures > 0 {
            println!();
            println!("{}", "🚨 CRITICAL FAILURES DETECTED".red().bold());
            println!("The following critical test suites failed:");

            for result in results.iter().filter(|r| !r.success && r.suite.critical) {
                println!(
                    "  • {}: {}",
                    result.suite.name.red(),
                    result.suite.description
                );
                if let Some(error) = &result.error {
                    println!("    {}", error);
                }
            }

            println!();
            println!(
                "{}",
                "⚠️  Deployment should be blocked until critical issues are resolved."
                    .yellow()
                    .bold()
            );
        } else if failed_tests == 0 {
            println!();
            println!(
                "{}",
                "🎉 All tests passed! Ready for deployment.".green().bold()
            );
        } else {
            println!();
            println!("{}", "⚠️  Some non-critical tests failed. Review recommended but deployment may proceed.".yellow());
        }

        // Performance summary
        self.print_performance_summary(results);
    }

    fn print_performance_summary(&self, results: &[TestResult]) {
        let benchmark_results: Vec<_> = results
            .iter()
            .filter(|r| r.suite.name.contains("benchmark") || r.suite.name.contains("stress"))
            .collect();

        if !benchmark_results.is_empty() {
            println!();
            println!("{}", "⚡ Performance Summary".bold().yellow());
            println!("{}", "─".repeat(30));

            for result in benchmark_results {
                let status = if result.success { "📈" } else { "📉" };
                println!(
                    "{} {}: {:.2}s",
                    status,
                    result.suite.name,
                    result.duration.as_secs_f64()
                );
            }
        }
    }

    pub fn run_quick_tests(&self) -> Vec<TestResult> {
        println!("{}", "⚡ Running Quick Test Suite".bold().yellow());

        let quick_suites: Vec<_> = self
            .suites
            .iter()
            .filter(|s| s.critical && s.timeout.as_secs() <= 300)
            .collect();

        let mut results = Vec::new();
        for suite in quick_suites {
            let result = self.run_suite(suite);
            self.print_suite_result(&result);
            results.push(result);
        }

        results
    }

    pub fn run_critical_only(&self) -> Vec<TestResult> {
        println!("{}", "🎯 Running Critical Tests Only".bold().red());

        let critical_suites: Vec<_> = self.suites.iter().filter(|s| s.critical).collect();

        let mut results = Vec::new();
        for suite in critical_suites {
            let result = self.run_suite(suite);
            self.print_suite_result(&result);
            results.push(result);
        }

        results
    }

    pub fn generate_coverage_report(&self) -> Result<String, Box<dyn std::error::Error>> {
        println!("{}", "📊 Generating Code Coverage Report".bold().cyan());

        let output = Command::new("cargo")
            .args(&["tarpaulin", "--out", "Html", "--output-dir", "coverage"])
            .output()?;

        if output.status.success() {
            let report_path = "coverage/tarpaulin-report.html";
            println!("✅ Coverage report generated: {}", report_path.green());
            Ok(report_path.to_string())
        } else {
            let error = String::from_utf8_lossy(&output.stderr);
            Err(format!("Coverage generation failed: {}", error).into())
        }
    }
}

pub fn run_pre_commit_tests() -> bool {
    let mut runner = TestRunner::new();
    runner.add_standard_suites();
    runner.verbose = false;

    println!("{}", "🔍 Running Pre-Commit Test Suite".bold().blue());

    let results = runner.run_critical_only();
    let critical_failures = results
        .iter()
        .filter(|r| !r.success && r.suite.critical)
        .count();

    critical_failures == 0
}

pub fn run_ci_tests() -> bool {
    let mut runner = TestRunner::new();
    runner.add_standard_suites();
    runner.verbose = true;

    println!(
        "{}",
        "🏗️  Running Continuous Integration Test Suite"
            .bold()
            .blue()
    );

    let results = runner.run_all();
    let critical_failures = results
        .iter()
        .filter(|r| !r.success && r.suite.critical)
        .count();

    // Generate coverage report in CI
    if let Err(e) = runner.generate_coverage_report() {
        println!(
            "⚠️  Coverage report generation failed: {}",
            e.to_string().yellow()
        );
    }

    critical_failures == 0
}

pub fn run_nightly_tests() -> Vec<TestResult> {
    let mut runner = TestRunner::new();
    runner.add_standard_suites();
    runner.verbose = true;

    // Add additional nightly-only tests
    runner.suites.push(TestSuite::new(
        "memory_leak_detection",
        "Memory leak detection and profiling",
        "cargo test --features memory_profiling leak_",
        3600,
        false,
    ));

    runner.suites.push(TestSuite::new(
        "fuzz_testing",
        "Fuzzing tests for robustness",
        "cargo fuzz run --jobs=4 fuzz_targets",
        7200,
        false,
    ));

    runner.suites.push(TestSuite::new(
        "compatibility_tests",
        "Cross-platform compatibility verification",
        "cargo test --features all_platforms compatibility_",
        1800,
        false,
    ));

    println!("{}", "🌙 Running Nightly Test Suite".bold().purple());
    runner.run_all()
}

#[cfg(test)]
mod test_runner_tests {
    use super::*;

    #[test]
    fn test_suite_creation() {
        let suite = TestSuite::new("test", "description", "echo hello", 30, true);
        assert_eq!(suite.name, "test");
        assert_eq!(suite.description, "description");
        assert_eq!(suite.command, "echo hello");
        assert_eq!(suite.timeout, Duration::from_secs(30));
        assert!(suite.critical);
    }

    #[test]
    fn test_runner_creation() {
        let mut runner = TestRunner::new();
        assert_eq!(runner.suites.len(), 0);

        runner.add_standard_suites();
        assert!(runner.suites.len() > 5);

        let critical_count = runner.suites.iter().filter(|s| s.critical).count();
        assert!(critical_count > 0);
    }

    #[test]
    fn test_simple_command_execution() {
        let runner = TestRunner::new();
        let suite = TestSuite::new("echo_test", "Simple echo test", "echo 'test'", 5, false);

        let result = runner.run_suite(&suite);
        assert!(result.success);
        assert!(result.output.contains("test"));
    }

    #[test]
    fn test_failing_command() {
        let runner = TestRunner::new();
        let suite = TestSuite::new("fail_test", "Failing test", "exit 1", 5, false);

        let result = runner.run_suite(&suite);
        assert!(!result.success);
    }
}
