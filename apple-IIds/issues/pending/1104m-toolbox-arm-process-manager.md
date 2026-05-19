---
name: Toolbox in ARM — Process Manager
phase: 11
status: pending
blockedBy: [1104a, 1104c, 1105]
parent: 1104
---

# 1104m — Toolbox in ARM: Process Manager

ARM-assembly port of the IIds Process Manager. Coordinates running
applications: launch, switch, terminate.

## current behavior

The Process Manager runs in emulation. Phase 9's preemptive
extension (issue 907) adds task-aware behavior.

## intended behavior

- Native ARM implementation of: `LaunchApplication`,
  `LaunchNextProcess`, `GetCurrentProcess`, `GetProcessInformation`,
  `GetNextProcess`, plus the process-record data structures.
- Integrates with the threading primitives (issue 1105) — each
  process is a task; foreground/background routing matches the
  scheduler's task priorities.
- Integrates with the Loader (1104c) for launching programs.

## suggested implementation steps

1. Study GS/OS Process Manager source.
2. Port the process-record management.
3. Port `LaunchApplication` (uses Loader 1104c).
4. Port the foreground / background switching.
5. Integrate with the scheduler from issue 1105.
6. Test: launch / quit several apps in sequence; verify
   correct foreground tracking and resource cleanup.

## related documents

- `issues/1104-iigs-toolbox-arm.md` — parent issue
- `issues/1104a-toolbox-arm-memory-manager.md`,
  `issues/1104c-toolbox-arm-loader.md`,
  `issues/1105-threading-primitives-arm.md` — dependencies

## notes

- Closely entangled with the scheduler. May benefit from being
  done in tandem with 1105.
