# Issue 011 - Implement Advanced Bash Bridge Features

## Current Behavior
The bash bridge in `libs/integration/bash_bridge.c` has basic command execution working but many advanced features are marked with TODO comments and stub implementations:
- Command timeout support (TODO)
- Input support for interactive commands (TODO) 
- Async execution with result polling (stub)
- Result caching system (stub)
- File watching via inotify (stub)
- Progress-ii JSON export (partial implementation)
- Performance timing (hardcoded 0.0)

## Intended Behavior
Complete implementation of all bash bridge features to provide robust, production-ready cross-language communication:
- Full timeout support with SIGTERM/SIGKILL escalation
- Interactive command support with stdin piping
- Async execution with background process management
- Intelligent result caching with TTL expiration
- Real-time file watching for progress-ii integration
- Comprehensive error handling and recovery
- Performance monitoring and timing

## Suggested Implementation Steps

### Phase 3A: Core Feature Completion
1. **Implement Command Timeout Support**
   - Add SIGALRM or timer-based timeout mechanism in `execute_bash_command()`
   - Implement escalating termination (SIGTERM → SIGKILL)
   - Add timeout status to BashResult structure
   - Test with long-running commands

2. **Add Input Support for Interactive Commands**
   - Modify `execute_bash_command()` to accept stdin input parameter
   - Implement pipe-based communication with child process
   - Add input validation and escape sequence handling
   - Test with interactive programs like `read` commands

3. **Implement Performance Timing**
   - Replace hardcoded `result->duration = 0.0` with real timing
   - Use `clock_gettime()` or `gettimeofday()` for microsecond precision
   - Add timing breakdown (fork, exec, wait phases)
   - Store timing data in BashResult structure

### Phase 3B: Async Execution System
4. **Implement Async Command Execution**
   - Replace async stub functions with real background process management
   - Create process tracking table with PID and status information
   - Implement `bash_start_async()`, `bash_poll_result()`, `bash_wait_result()`
   - Add process cleanup and zombie prevention

5. **Add Process Management Features**
   - Implement process groups for complex command chains
   - Add signal handling for graceful async termination
   - Create process status monitoring with state machine
   - Handle process output buffering and streaming

### Phase 3C: Caching and File Watching
6. **Implement Result Caching System**
   - Replace caching stubs with real hash table implementation
   - Add TTL (Time To Live) expiration for cached results
   - Implement cache size limits with LRU eviction
   - Add cache statistics and performance monitoring

7. **Implement File Watching via Inotify**
   - Replace `watch_progress_files()` stub with real inotify implementation
   - Add recursive directory watching capability
   - Implement event filtering and batching
   - Create callback system for file change notifications

### Phase 3D: Progress-II Integration Enhancement
8. **Complete JSON Export/Import Functions**
   - Enhance `export_character_to_progress()` with comprehensive character data
   - Implement `import_character_from_progress()` for bidirectional sync
   - Add validation for JSON schema compliance
   - Test with real progress-ii project integration

9. **Add Structured Command Support**
   - Implement `execute_bash_structured()` with parameter sanitization
   - Add command template system for safe parameter injection
   - Create predefined command patterns for progress-ii operations
   - Add command composition and chaining support

### Phase 3E: Error Handling and Monitoring
10. **Enhance Error Handling**
    - Add comprehensive error codes for all failure modes
    - Implement retry logic with exponential backoff
    - Add logging integration for debugging and monitoring
    - Create error recovery strategies for common failures

11. **Add Monitoring and Diagnostics**
    - Implement resource usage monitoring (memory, CPU, file handles)
    - Add command execution statistics and performance metrics
    - Create health check functions for bash bridge status
    - Add diagnostic dumps for troubleshooting

## Dependencies
- inotify system calls for file watching
- Hash table implementation for caching (or create custom)
- JSON parsing/generation library for progress-ii integration
- POSIX signal handling and process management
- High-resolution timing functions

## Verification Criteria
- All TODO comments replaced with working implementations
- Timeout handling prevents runaway processes
- Interactive commands work with input/output
- Async execution allows parallel command processing
- File watching detects progress-ii changes in real-time
- Caching improves performance for repeated operations
- Resource usage remains bounded under load

## Estimated Complexity
**Medium-High** - Involves system programming concepts:
- POSIX process management and signals
- File system monitoring with inotify
- Inter-process communication and pipes
- Memory management for caching systems
- Error handling and resource cleanup

## Related Issues
- Issue 008: Progress-ii integration (provides context)
- Issue 010: Lua integration (may call bash bridge from Lua)
- Future: Advanced cross-project workflows
- Future: Distributed execution across projects

## Notes
Focus on robustness and error handling - bash bridge is critical infrastructure for cross-project communication. All features should gracefully degrade and provide meaningful error messages.