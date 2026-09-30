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
├── threadpool/          # General-purpose threading library
│   ├── docs/            # Library documentation
│   ├── src/             # Source files
│   └── tests/           # Test suite
│
└── zip/                 # Zip packer and metered reader, plain Lua
    ├── src/             # Source files (each with an .info.md)
    └── tests/           # Checks, run under every Lua present
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

### zip (In Progress)

A zip packer and reader in plain Lua (LuaJIT and Lua 5.3/5.4), so no
project needs the `zip` or `unzip` programs:
- The reader checks the whole structure before making a byte, then counts
  every byte before it exists, so zip bombs stop at the agreed size.
- Links arrive as notes, never links.
- The packer counts the unpacked size exactly.

**Origin:** rao-chat issue 216e. **Consumers:** rao-chat, rmail. See
`zip/README.md`.

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
