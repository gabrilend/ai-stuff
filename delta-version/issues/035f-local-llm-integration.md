# Issue 035f: Local LLM Integration for Ambiguous Decisions

## Parent Issue
- **Issue 035**: Project History Reconstruction from Issue Files

## Current Behavior

The `reconstruct-history.sh` script uses deterministic heuristics for:
- Issue ordering (topological sort based on Dependencies/Blocks fields)
- Date estimation (explicit dates, mtime fallback, interpolation)
- File association (path mentions, naming conventions)

When these heuristics are ambiguous or conflicting, the script falls back to numerical ordering or skips the decision entirely. This can lead to suboptimal history reconstruction when human judgment would help.

## Intended Behavior

Add **optional** local LLM integration to resolve ambiguous decisions with a "triple-check" consensus pattern for reliability.

### Key Features

1. **Triple-Check Pattern**: Query LLM 3 times, require 2/3 consensus
2. **Success/Failure Tracking**: Permanent counters for debugging hallucination rates
3. **Graceful Fallback**: Always fall back to deterministic methods if LLM unavailable or no consensus
4. **Configurable**: Disabled by default, user opts in with `--llm` flag

### Use Cases

| Scenario | Without LLM | With LLM |
|----------|-------------|----------|
| Two issues with no explicit dependencies | Numerical order | Ask "which should come first?" |
| File could match multiple issues | First match wins | Ask "which issue created this file?" |
| Ambiguous date from corrupted mtime | Interpolate from neighbors | Ask "when was this likely completed?" |

## Suggested Implementation Steps

### 1. Add Configuration Section
```bash
# -- {{{ LLM Configuration (035f)
LLM_ENABLED="${LLM_ENABLED:-false}"
LLM_MODEL="${LLM_MODEL:-llama3}"
LLM_VERIFY_COUNT="${LLM_VERIFY_COUNT:-3}"
LLM_STATS_FILE="${LLM_STATS_FILE:-$HOME/.config/reconstruct-history/llm-stats.txt}"
# }}}
```

### 2. Implement Stats Tracking
```bash
# -- {{{ record_llm_result
record_llm_result() {
    local result="$1"  # "success" or "failure"
    # Increment counter in stats file, update ratio
}
# }}}

# -- {{{ show_llm_stats
show_llm_stats() {
    # Display success/failure counts and percentage
}
# }}}
```

### 3. Implement Core LLM Functions
```bash
# -- {{{ query_local_llm
query_local_llm() {
    local prompt="$1"
    # Query ollama, return response
}
# }}}

# -- {{{ llm_triple_check
llm_triple_check() {
    local question="$1"
    # Query 3 times, return JSON with all responses
}
# }}}

# -- {{{ llm_get_consensus
llm_get_consensus() {
    local json_responses="$1"
    # Parse JSON, check for 2/3 agreement
    # Record success/failure
    # Return consensus or "none"
}
# }}}
```

### 4. Implement Decision Functions
```bash
# -- {{{ resolve_ambiguous_ordering
resolve_ambiguous_ordering() {
    local issue1="$1"
    local issue2="$2"
    # Ask LLM which should come first
    # Fall back to numerical if no consensus
}
# }}}

# -- {{{ resolve_ambiguous_file_association
resolve_ambiguous_file_association() {
    local file="$1"
    local issue1="$2"
    local issue2="$3"
    # Ask LLM which issue created the file
}
# }}}
```

### 5. Add CLI Flags
```bash
--llm              Enable LLM integration (requires ollama)
--llm-model NAME   Specify model (default: llama3)
--llm-stats        Show LLM success/failure statistics
--llm-reset-stats  Reset statistics counters
```

### 6. Integrate with Existing Functions
- In `topological_sort_issues()`: Use `resolve_ambiguous_ordering()` for ties
- In `associate_files_with_issues()`: Use `resolve_ambiguous_file_association()` for conflicts

## Files to Modify

- `delta-version/scripts/reconstruct-history.sh`:
  - Add LLM configuration section
  - Add `record_llm_result()`, `show_llm_stats()`
  - Add `query_local_llm()`, `llm_triple_check()`, `llm_get_consensus()`
  - Add `resolve_ambiguous_ordering()`, `resolve_ambiguous_file_association()`
  - Update `parse_args()` with new flags
  - Update `show_help()` with LLM options

## Dependencies

- **ollama** (or compatible LLM runner) must be installed and running
- **jq** for JSON parsing of responses
- Model must be pulled: `ollama pull llama3`

## Testing Strategy

### Test 1: Stats File Creation
```bash
# Run with LLM enabled on a project
./reconstruct-history.sh --llm --dry-run /path/to/project

# Check stats file exists
cat ~/.config/reconstruct-history/llm-stats.txt
```

### Test 2: Triple-Check Consensus
```bash
# Mock test - verify 2/3 agreement detection
# Responses: ["001", "001", "002"] -> consensus "001"
# Responses: ["001", "002", "003"] -> no consensus
```

### Test 3: Graceful Fallback
```bash
# With ollama stopped, verify script still works
systemctl stop ollama
./reconstruct-history.sh --llm /path/to/project
# Should fall back to numerical ordering
```

### Test 4: Stats Display
```bash
./reconstruct-history.sh --llm-stats
# LLM Statistics:
#   Successes: 42
#   Failures:  7
#   Ratio:     42/7 (86% success rate)
```

## Related Documents
- **Issue 035**: Parent issue for project history reconstruction
- **Issue 035a-035d**: Completed sub-issues
- **Issue 035e**: History rewriting with rebase (pending)

## Metadata
- **Priority**: Low (optional enhancement)
- **Complexity**: Medium
- **Dependencies**: Issue 035a, 035b, 035c, 035d
- **Blocks**: None (optional feature)
- **Status**: In Progress

## Success Criteria

- [ ] LLM configuration variables added to script
- [ ] `record_llm_result()` increments counters in stats file
- [ ] `show_llm_stats()` displays statistics with percentage
- [ ] `query_local_llm()` sends prompts to ollama
- [ ] `llm_triple_check()` queries 3 times, returns JSON
- [ ] `llm_get_consensus()` detects 2/3 agreement, records result
- [ ] `resolve_ambiguous_ordering()` asks LLM for issue order
- [ ] `--llm` flag enables LLM integration
- [ ] `--llm-model` flag changes model
- [ ] `--llm-stats` flag shows statistics
- [ ] Script works normally when ollama unavailable (graceful fallback)
- [ ] Help text documents LLM options
