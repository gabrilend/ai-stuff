# Issue 016: Design Keyword Markup Language

## Current Behavior

There is no standardized markup language for creating dynamic tickets with auto-substituted content. Template tickets need a way to specify placeholders that can be replaced with project-specific data gathered via bash commands, but no syntax or processing framework exists.

## Intended Behavior

Design a lightweight, bash-based markup language that:
1. **Keyword Syntax**: Clear, unambiguous placeholder format that won't conflict with markdown
2. **Parameter Support**: Keywords that can accept parameters for customization
3. **Bash Integration**: Direct mapping from keywords to executable bash commands
4. **Error Handling**: Graceful handling of failed command execution
5. **Extensibility**: Easy addition of new keyword types via configuration

## Suggested Implementation Steps

### 1. Keyword Syntax Design
```
Primary format: ][keyword_name[]
Parameterized format: ][keyword_name[param1,param2][]
Escaped format: \][literal_bracket_text[]
```

### 2. Keyword Classification System
```
Data Keywords: ][project_name[] ][file_count[] ][last_modified[]
Analysis Keywords: ][function_usage[function_name][] ][dependency_list[]
Statistics Keywords: ][size_stats[] ][commit_count[] ][src_files[]
Meta Keywords: ][current_date[] ][generation_time[] ][ticket_id[]
```

### 3. Parameter Processing Design
```bash
# -- {{{ parse_keyword_parameters
function parse_keyword_parameters() {
    local keyword_string="$1"
    
    # Extract keyword name and parameters
    # Parse parameter list (comma-separated)
    # Validate parameter syntax and types
    # Return structured parameter data
}
# }}}
```

### 4. Command Mapping Framework
```ini
# keyword-definitions.conf
[data]
project_name="basename $(pwd)"
file_count="find . -type f | wc -l"
last_modified="stat -c %Y . | date -d @- '+%Y-%m-%d'"

[analysis]
function_usage="grep -r 'PARAM1' --include='*.lua' --include='*.c' ./src/ | wc -l 2>/dev/null || echo 0"
dependency_list="find ./libs -maxdepth 1 -type d | tail -n +2 | basename -a | tr '\n' ', '"

[statistics]
size_stats="du -sh . | cut -f1"
commit_count="git rev-list --count HEAD 2>/dev/null || echo 0"
```

### 5. Error Handling Strategy
```bash
# -- {{{ handle_keyword_error
function handle_keyword_error() {
    local keyword="$1"
    local error_msg="$2"
    
    case "$ERROR_MODE" in
        "placeholder") echo "[ERROR: $keyword]" ;;
        "remove") echo "" ;;
        "verbose") echo "[ERROR: $keyword - $error_msg]" ;;
        "fail") exit 1 ;;
    esac
}
# }}}
```

### 6. Keyword Validation Framework
```bash
# -- {{{ validate_keyword_syntax
function validate_keyword_syntax() {
    local template_content="$1"
    
    # Find all ][...[] patterns
    # Validate keyword names exist in configuration
    # Check parameter syntax and count
    # Report any invalid or unknown keywords
}
# }}}
```

## Implementation Details

### Keyword Syntax Specification
```
Valid keyword formats:
][project_name[]           - Simple data keyword
][file_count[]             - Statistics keyword
][function_usage[main][]   - Analysis keyword with parameter
][size_stats[]             - Computed data keyword

Invalid formats:
][invalid-chars![]         - Invalid characters in name
][unclosed[                - Unclosed bracket
nested][inner[]outer[]     - Nested keywords (not supported)
```

### Parameter Processing Rules
```
Parameter syntax: ][keyword[param1,param2,param3][]
- Parameters are comma-separated
- No spaces around commas
- Parameter values can contain alphanumeric, underscore, hyphen
- Maximum 5 parameters per keyword
- Parameter validation depends on keyword type
```

### Command Substitution Framework
```bash
# Template for parameterized commands
function_usage="grep -r 'PARAM1' --include='*.PARAM2' ./PARAM3/ | wc -l 2>/dev/null || echo 0"

# Parameter substitution:
# PARAM1 -> first parameter value
# PARAM2 -> second parameter value  
# PARAM3 -> third parameter value
```

### Configuration File Structure
```ini
# ticket-keywords.conf
[metadata]
version=1.0
error_mode=placeholder
timeout=10

[data_keywords]
# Simple data collection keywords
project_name="basename $(pwd)"
current_date="date '+%Y-%m-%d'"

[analysis_keywords] 
# Keywords requiring parameter substitution
function_usage="grep -r 'PARAM1' --include='*.lua' --include='*.c' ./src/ | wc -l 2>/dev/null || echo 0"
comment_style="grep -E '^[[:space:]]*PARAM1' --include='*.PARAM2' -r ./src/ | head -5"

[statistics_keywords]
# Computational and summary keywords
file_count="find . -name '*.lua' -o -name '*.c' -o -name '*.rs' | wc -l"
size_stats="du -sh . 2>/dev/null | cut -f1 || echo 'unknown'"
```

## Related Documents
- `017-implement-keyword-processing-engine.md` - Implements this design
- `003-dynamic-ticket-distribution-system.md` - Parent ticket
- Template tickets using this markup language

## Tools Required
- Text parsing and regular expressions
- Configuration file processing
- Bash command substitution
- Parameter validation utilities

## Metadata
- **Priority**: High
- **Complexity**: Medium
- **Estimated Time**: 1-1.5 hours
- **Dependencies**: None
- **Impact**: Foundation for dynamic ticket system

## Success Criteria
- Clear, unambiguous keyword syntax defined
- Parameter processing rules established
- Command mapping framework designed
- Error handling strategy specified
- Configuration file format standardized
- Keyword validation approach defined
- Foundation ready for implementation of processing engine