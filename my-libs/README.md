# My-Libs

Shared library infrastructure for reusable components across projects.

## Structure

```
my-libs/
├── issues/              # Shared issue tracking for all libraries
│   ├── progress.md      # Overall progress tracking
│   ├── 800*.md          # Threadpool library issues
│   └── completed/       # Completed issue archive
│
└── threadpool/          # General-purpose threading library
    ├── docs/            # Library documentation
    ├── src/             # Source files
    └── tests/           # Test suite
```

## Libraries

### threadpool (In Progress)

General-purpose threading infrastructure with:
- Worker pool with automatic core detection
- Ring buffer task lists
- Load-balanced task distribution
- Optional sync module for atomic pointer swaps
- Optional updater module with self-evaluating helpers

**Origin:** Extracted from world-edit-to-execute render system (Phase 8)

## Issue Conventions

Issues follow the same conventions as other projects:
- Named `{PHASE}{ID}-{description}.md`
- Sub-issues: `{PHASE}{ID}{letter}-{description}.md`
- Sections: Current Behavior, Intended Behavior, Suggested Implementation Steps

## Usage

Libraries are designed to be included via:
1. Direct source inclusion (copy files)
2. Symlink into project libs/ directory
3. Include path addition (`-I/path/to/my-libs/threadpool/src`)
