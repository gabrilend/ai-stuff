# Keyword Markup Language Specification

## Overview

The Keyword Markup Language (KML) is a lightweight template syntax for creating dynamic issue tickets with auto-substituted content. Keywords are placeholders that get replaced with project-specific data gathered via bash commands.

## Version

- **Specification Version**: 1.0
- **Issue**: 016-design-keyword-markup-language
- **Status**: Approved

---

## Syntax Specification

### Primary Format

```
][keyword_name[]
```

- **Opening delimiter**: `][` (right bracket, left bracket)
- **Closing delimiter**: `[]` (left bracket, right bracket)
- **Keyword name**: lowercase alphanumeric with underscores

### Parameterized Format

```
][keyword_name[param1,param2,param3][]
```

- Parameters are enclosed in inner brackets `[...]`
- Multiple parameters are comma-separated
- No spaces around commas
- Maximum 5 parameters per keyword

### Escaped Format

```
\][literal_text[]
```

- Backslash before opening delimiter prevents substitution
- Outputs the literal text `][literal_text[]`

---

## Keyword Naming Rules

### Valid Names

- Lowercase letters: `a-z`
- Numbers: `0-9` (not as first character)
- Underscores: `_`
- Minimum length: 2 characters
- Maximum length: 32 characters

### Examples

```
Valid:
  ][project_name[]
  ][file_count[]
  ][src_files_lua[]
  ][commit_count_30d[]

Invalid:
  ][Project_Name[]     - Uppercase not allowed
  ][file-count[]       - Hyphens not allowed
  ][1_invalid[]        - Cannot start with number
  ][x[]                - Too short (min 2 chars)
  ][has spaces[]       - Spaces not allowed
```

---

## Parameter Specification

### Parameter Syntax

```
][keyword[param1,param2,param3][]
```

### Parameter Rules

1. **Delimiter**: Comma `,` separates parameters
2. **Whitespace**: No spaces around commas or brackets
3. **Maximum**: 5 parameters per keyword
4. **Character set**: Alphanumeric, underscore, hyphen, dot, forward slash
5. **Quoting**: Not supported (reserved for future)

### Parameter Substitution in Commands

Commands use positional placeholders:
- `PARAM1` → First parameter value
- `PARAM2` → Second parameter value
- `PARAM3` → Third parameter value
- `PARAM4` → Fourth parameter value
- `PARAM5` → Fifth parameter value

### Examples

```
Template: ][function_usage[main,lua][]
Command:  grep -r 'PARAM1' --include='*.PARAM2' ./src/ | wc -l
Resolved: grep -r 'main' --include='*.lua' ./src/ | wc -l

Template: ][file_search[TODO,src,5][]
Command:  grep -rn 'PARAM1' ./PARAM2 | head -PARAM3
Resolved: grep -rn 'TODO' ./src | head -5
```

---

## Keyword Categories

### Data Keywords

Simple data retrieval with no parameters.

| Keyword | Description | Command |
|---------|-------------|---------|
| `project_name` | Current project directory name | `basename $(pwd)` |
| `project_path` | Absolute path to project | `pwd` |
| `current_date` | Today's date (YYYY-MM-DD) | `date '+%Y-%m-%d'` |
| `current_time` | Current time (HH:MM:SS) | `date '+%H:%M:%S'` |
| `current_user` | Username running script | `whoami` |
| `git_branch` | Current git branch | `git branch --show-current 2>/dev/null \|\| echo 'none'` |
| `git_remote` | Remote repository URL | `git remote get-url origin 2>/dev/null \|\| echo 'none'` |

### Statistics Keywords

Computed metrics about the project.

| Keyword | Description | Command |
|---------|-------------|---------|
| `file_count` | Total file count | `find . -type f \| wc -l` |
| `dir_count` | Total directory count | `find . -type d \| wc -l` |
| `size_total` | Project size (human) | `du -sh . 2>/dev/null \| cut -f1` |
| `commit_count` | Total git commits | `git rev-list --count HEAD 2>/dev/null \|\| echo 0` |
| `src_files` | Source file count | `find ./src -type f 2>/dev/null \| wc -l` |
| `issue_count` | Issue file count | `find ./issues -name '*.md' -type f 2>/dev/null \| wc -l` |
| `completed_issues` | Completed issue count | `find ./issues/completed -name '*.md' -type f 2>/dev/null \| wc -l` |

### Analysis Keywords (Parameterized)

Keywords that accept parameters for customized queries.

| Keyword | Parameters | Description |
|---------|------------|-------------|
| `function_usage` | `name,ext` | Count occurrences of function name in files with extension |
| `file_search` | `pattern,dir,limit` | Search for pattern in directory, limit results |
| `grep_count` | `pattern,ext` | Count lines matching pattern in files |
| `file_list` | `ext,dir` | List files with extension in directory |
| `recent_files` | `days,ext` | Files modified in last N days |

### Meta Keywords

Information about the template processing itself.

| Keyword | Description | Command |
|---------|-------------|---------|
| `generation_date` | When template was processed | `date '+%Y-%m-%d %H:%M:%S'` |
| `template_name` | Source template filename | (internal) |
| `kml_version` | KML specification version | (internal: "1.0") |
| `ticket_id` | Generated ticket identifier | (internal: auto-generated) |

---

## Error Handling

### Error Modes

The processor supports multiple error handling strategies:

| Mode | Behavior | Output |
|------|----------|--------|
| `placeholder` | Replace with error marker | `[ERROR: keyword_name]` |
| `remove` | Remove the keyword entirely | (empty string) |
| `verbose` | Include error details | `[ERROR: keyword_name - message]` |
| `fail` | Stop processing, exit with error | (process terminates) |

### Error Conditions

1. **Unknown keyword**: Keyword name not in configuration
2. **Command failure**: Bash command returns non-zero exit code
3. **Timeout**: Command exceeds configured timeout
4. **Parameter mismatch**: Wrong number of parameters provided
5. **Invalid syntax**: Malformed keyword structure

### Default Behavior

- Default error mode: `placeholder`
- Default timeout: 10 seconds
- Commands run with `set +e` (don't fail on error)

---

## Escape Sequences

### Preventing Substitution

Use backslash to prevent keyword processing:

```
Input:  \][project_name[]
Output: ][project_name[]
```

### Double Backslash

For literal backslash before keyword:

```
Input:  \\][project_name[]
Output: \<substituted value>
```

### In Markdown Context

The `][` delimiter was chosen to avoid conflicts with:
- Markdown links: `[text](url)`
- Markdown images: `![alt](src)`
- Markdown references: `[ref]: url`

---

## Configuration File Format

### Location

```
$PROJECT_DIR/config/ticket-keywords.conf
or
$DELTA_VERSION_DIR/config/ticket-keywords.conf (default)
```

### Structure

```ini
[metadata]
version=1.0
error_mode=placeholder
timeout=10

[data_keywords]
project_name=basename $(pwd)
current_date=date '+%Y-%m-%d'
git_branch=git branch --show-current 2>/dev/null || echo 'none'

[statistics_keywords]
file_count=find . -type f | wc -l
commit_count=git rev-list --count HEAD 2>/dev/null || echo 0
src_files=find ./src -type f 2>/dev/null | wc -l

[analysis_keywords]
function_usage=grep -r 'PARAM1' --include='*.PARAM2' ./src/ | wc -l 2>/dev/null || echo 0
file_search=grep -rn 'PARAM1' ./PARAM2 2>/dev/null | head -PARAM3
grep_count=grep -r 'PARAM1' --include='*.PARAM2' . | wc -l

[meta_keywords]
generation_date=date '+%Y-%m-%d %H:%M:%S'
kml_version=echo '1.0'
```

### Section Descriptions

| Section | Purpose |
|---------|---------|
| `[metadata]` | Processor configuration settings |
| `[data_keywords]` | Simple data retrieval commands |
| `[statistics_keywords]` | Computed metric commands |
| `[analysis_keywords]` | Parameterized analysis commands |
| `[meta_keywords]` | Template processing metadata |

---

## Processing Algorithm

### Step 1: Parse Template

1. Read template content
2. Find all `][...[]` patterns
3. Check for escape sequences (`\][`)
4. Build list of keywords to process

### Step 2: Validate Keywords

1. Check keyword name format
2. Verify keyword exists in configuration
3. Validate parameter count matches definition
4. Report any validation errors

### Step 3: Execute Commands

For each valid keyword:
1. Retrieve command from configuration
2. Substitute parameters (PARAM1, PARAM2, etc.)
3. Execute command with timeout
4. Capture stdout as result

### Step 4: Substitute Results

1. Replace each keyword occurrence with result
2. Handle errors according to error_mode
3. Process escape sequences
4. Output final content

---

## Template Example

### Input Template

```markdown
# Project Report: ][project_name[]

Generated: ][generation_date[]
Branch: ][git_branch[]

## Statistics

- Total files: ][file_count[]
- Source files: ][src_files[]
- Git commits: ][commit_count[]
- Project size: ][size_total[]

## Issues

- Total issues: ][issue_count[]
- Completed: ][completed_issues[]

## Code Analysis

Function `main` usage: ][function_usage[main,lua][] occurrences

## Notes

To use literal brackets: \][not_a_keyword[]
```

### Output

```markdown
# Project Report: my-awesome-project

Generated: 2026-01-04 14:30:00
Branch: master

## Statistics

- Total files: 234
- Source files: 45
- Git commits: 127
- Project size: 2.3M

## Issues

- Total issues: 23
- Completed: 18

## Code Analysis

Function `main` usage: 12 occurrences

## Notes

To use literal brackets: ][not_a_keyword[]
```

---

## Reserved Keywords

The following keywords are reserved and cannot be redefined:

| Keyword | Reason |
|---------|--------|
| `kml_version` | Internal: specification version |
| `template_name` | Internal: source template |
| `ticket_id` | Internal: generated identifier |
| `generation_date` | Internal: processing timestamp |
| `error` | Reserved for error output |
| `debug` | Reserved for debug output |

---

## Future Considerations

### Planned Extensions (v2.0)

1. **Conditional keywords**: `][if_exists[file][]...][endif[]`
2. **Loops**: `][foreach[file,src/*.lua][]...][endfor[]`
3. **Nested keywords**: `][outer[][inner[]][]]`
4. **Quoted parameters**: `][search["hello world",src][]`
5. **Default values**: `][keyword|default_value[]`

### Compatibility

- v1.x templates will remain compatible with v2.0+ processors
- New features will use syntax that is invalid in v1.x (parser errors, not silent failures)

---

## Related Documents

- [Issue 017: Implement Keyword Processing Engine](../issues/017-implement-keyword-processing-engine.md)
- [Issue 003: Dynamic Ticket Distribution System](../issues/003-dynamic-ticket-distribution-system.md)
- [ticket-keywords.conf](../config/ticket-keywords.conf)
