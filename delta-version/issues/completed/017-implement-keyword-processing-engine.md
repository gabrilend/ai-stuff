# Issue 017: Implement Keyword Processing Engine

## Current Behavior

The keyword markup language has been designed (Issue 016), but there is no implementation for parsing templates and executing the bash commands associated with keywords. Templates with `][keyword[]` placeholders cannot be processed into final tickets with project-specific data.

## Intended Behavior

Implement a robust keyword processing engine that:
1. **Template Parsing**: Extract keywords and parameters from template content
2. **Command Execution**: Execute configured bash commands for each keyword
3. **Parameter Substitution**: Replace PARAM1, PARAM2, etc. in commands with actual values
4. **Result Substitution**: Replace keywords in template with command results
5. **Error Handling**: Gracefully handle failed commands and invalid keywords

## Suggested Implementation Steps

### 1. Template Parsing Engine
```bash
# -- {{{ parse_template_keywords
function parse_template_keywords() {
    local template_content="$1"
    
    # Use regex to find all ][...[] patterns
    # Extract keyword names and parameters
    # Validate keyword syntax
    # Return list of keywords with their positions
}
# }}}
```

### 2. Configuration Loading System
```bash
# -- {{{ load_keyword_config
function load_keyword_config() {
    local config_file="$1"
    
    # Parse INI-style configuration file
    # Load keyword-to-command mappings
    # Validate command syntax
    # Store in associative arrays for fast lookup
}
# }}}
```

### 3. Parameter Substitution Engine
```bash
# -- {{{ substitute_parameters
function substitute_parameters() {
    local command_template="$1"
    local parameters="$2"
    
    # Parse parameter list into array
    # Replace PARAM1, PARAM2, etc. in command
    # Validate parameter count matches expectations
    # Return executable command string
}
# }}}
```

### 4. Command Execution Framework
```bash
# -- {{{ execute_keyword_command
function execute_keyword_command() {
    local keyword="$1"
    local parameters="$2"
    local project_dir="$3"
    
    # Look up command for keyword
    # Substitute parameters in command
    # Execute command in project context
    # Capture output and error status
    # Handle timeouts and failures
}
# }}}
```

### 5. Template Substitution Engine
```bash
# -- {{{ substitute_keywords_in_template
function substitute_keywords_in_template() {
    local template_content="$1"
    local keyword_results="$2"
    
    # Replace each ][keyword[] with its result
    # Preserve template structure and formatting
    # Handle multi-line results appropriately
    # Escape special characters if needed
}
# }}}
```

### 6. Error Recovery System
```bash
# -- {{{ handle_keyword_failures
function handle_keyword_failures() {
    local keyword="$1"
    local error_msg="$2"
    local error_mode="$3"
    
    # Apply configured error handling strategy
    # Log errors for debugging
    # Provide fallback values when appropriate
    # Continue processing other keywords
}
# }}}
```

## Implementation Details

### Keyword Parsing Implementation
```bash
# -- {{{ extract_keywords_regex
function extract_keywords_regex() {
    local content="$1"
    
    # Regex pattern: ]\[[a-zA-Z_][a-zA-Z0-9_]*(\[[^\]]*\])?\[\]
    # Captures: keyword name and optional parameter block
    echo "$content" | grep -oE '\]\[[a-zA-Z_][a-zA-Z0-9_]*(\[[^\]]*\])?\[\]'
}
# }}}

# -- {{{ parse_keyword_components
function parse_keyword_components() {
    local keyword_match="$1"
    
    # Extract: ][keyword_name[param1,param2][]
    # Into: keyword_name="keyword_name", params="param1,param2"
    local keyword_name
    local parameters
    
    # Parse using bash parameter expansion and regex
}
# }}}
```

### Configuration Loading Implementation
```bash
declare -A keyword_commands
declare -A keyword_categories

# -- {{{ load_config_file
function load_config_file() {
    local config_file="$1"
    local current_section=""
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Section headers: [section_name]
        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi
        
        # Key-value pairs: keyword_name="command"
        if [[ "$line" =~ ^([^=]+)=(.+)$ ]]; then
            local key="${BASH_REMATCH[1]// /}"
            local value="${BASH_REMATCH[2]}"
            keyword_commands["$key"]="$value"
            keyword_categories["$key"]="$current_section"
        fi
    done < "$config_file"
}
# }}}
```

### Parameter Substitution Implementation
```bash
# -- {{{ substitute_command_parameters
function substitute_command_parameters() {
    local command="$1"
    local params_string="$2"
    
    # Convert "param1,param2,param3" to array
    IFS=',' read -ra params <<< "$params_string"
    
    # Replace PARAM1, PARAM2, etc. in command
    local result="$command"
    for i in "${!params[@]}"; do
        local param_num=$((i + 1))
        local param_value="${params[$i]// /}"  # Remove spaces
        result="${result//PARAM$param_num/$param_value}"
    done
    
    echo "$result"
}
# }}}
```

### Command Execution with Context
```bash
# -- {{{ execute_in_project_context
function execute_in_project_context() {
    local command="$1"
    local project_dir="$2"
    local timeout="${3:-10}"
    
    # Change to project directory
    (
        cd "$project_dir" || exit 1
        
        # Execute command with timeout
        timeout "$timeout" bash -c "$command" 2>/dev/null || {
            echo "[command failed]"
            exit 1
        }
    )
}
# }}}
```

### Template Processing Pipeline
```bash
# -- {{{ process_template_file
function process_template_file() {
    local template_file="$1"
    local project_dir="$2"
    local config_file="$3"
    
    # Load configuration
    load_config_file "$config_file"
    
    # Read template content
    local content=$(<"$template_file")
    
    # Extract all keywords
    local keywords
    keywords=$(extract_keywords_regex "$content")
    
    # Process each keyword
    while IFS= read -r keyword_match; do
        # Parse keyword components
        parse_keyword_components "$keyword_match"
        
        # Execute command and get result
        local result
        result=$(execute_keyword_command "$keyword_name" "$parameters" "$project_dir")
        
        # Substitute in template
        content="${content//$keyword_match/$result}"
    done <<< "$keywords"
    
    echo "$content"
}
# }}}
```

## Related Documents
- `016-design-keyword-markup-language.md` - Provides design specification
- `018-create-project-discovery-system.md` - Uses processing engine
- `003-dynamic-ticket-distribution-system.md` - Parent ticket

## Tools Required
- Advanced bash text processing
- Regular expression matching
- Associative array manipulation
- Process execution and timeout handling
- Configuration file parsing

## Metadata
- **Priority**: High
- **Complexity**: High
- **Estimated Time**: 2-2.5 hours
- **Dependencies**: Issue 016 (markup language design)
- **Blocks**: Issue 019 (ticket distribution engine)
- **Impact**: Core functionality of dynamic ticket system

## Success Criteria
- Template files parsed correctly for keywords
- Keyword configuration loaded and validated
- Parameters properly substituted in commands
- Commands executed in correct project context
- Results substituted back into templates accurately
- Error handling prevents system failure
- Performance acceptable for multiple keywords per template
- Engine ready for integration with project discovery system

---

## What Happened (2026-11-02)

Built as `delta-version/scripts/libs/kml.lua` (the engine) and
`delta-version/scripts/process-template.lua` (its command line), each with an
`.info.md`, and tested by `scripts/test-process-template.sh <monorepo>`
(39 checks). Every success criterion above holds: templates are parsed,
the configuration is loaded and checked, parameters are substituted, commands
run in the project's folder under a time limit, results go back in place,
failures are handled by the four error modes without stopping the rest, and
each distinct command runs once per template however often it is used.

**Decisions:**
- **Lua, not the bash sketched above.** Escapes (`\][`, `\\][`), placeholders
  next to ordinary `][` text and per-placeholder errors are a small scanner in
  Lua and a regex tangle in bash; the commands themselves still run in bash.
- **Parameters are held to the specification's character set** (letters,
  digits, `_ - . /`, at most five, none empty), because they are pasted into
  shell commands. Anything wider is an error and runs nothing; the test tries
  `;`, a space and `$(...)`.
- **A placeholder must give exactly as many parameters as its command's
  highest `PARAMn`**, the specification's "parameter mismatch".
- **Malformed placeholders are errors, not text**: `][Project_Name[]` is
  reported rather than passed through, so a typo shows. `][` followed by
  anything but a name-like run and `[` (for instance the `][ name ][` markers
  of the directory-tree generator, 044) is plain text.
- **Configuration layering**: the specification said the project's file *or*
  delta-version's; the engine reads delta-version's and layers the project's
  over it, so a project names only what it changes. `--config` uses one file
  alone. The specification now says so.
- **The engine's own keywords win**: `kml_version`, `template_name`,
  `ticket_id` and `generation_date` are filled internally, and configuration
  entries with those names are ignored (the shipped file's `generation_date`
  and `kml_version` commands gave the same values anyway). `error` and
  `debug` are always errors, as reserved.
- **Ticket ids** default to `T-YYYYMMDD-HHMMSS-xxxx`; `--ticket-id` sets one,
  for the distribution engine (019) to number tickets its own way.
- `--check` validates a template without running anything, and `--list` shows
  the keywords with their parameter slots; neither was asked for, both are
  what a template writer needs first.
- Fixed in the shipped configuration: `file_list` used `tr '\n' ', '`, which
  maps newlines to commas only and left a trailing comma; it now joins names
  with ", ".

