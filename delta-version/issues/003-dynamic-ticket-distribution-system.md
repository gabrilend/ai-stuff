# Issue 003-MASTER: Dynamic Ticket Distribution System (BROKEN DOWN)

## Current Behavior

Currently, when organizational changes or dependency updates need to be communicated across multiple projects in `/home/ritz/programming/ai-stuff/`, there is no systematic way to:

### Manual Process Issues
- **Individual Notifications**: Must manually create separate tickets in each project directory
- **Inconsistent Information**: Each project might receive different versions of the same information
- **Static Content**: Tickets contain generic information without project-specific context
- **No Automation**: Dependency updates, style changes, or meta-project decisions require manual distribution

### Missing Capabilities
- **Auto-gathered Statistics**: No automatic collection of project-specific data (file counts, function usage, etc.)
- **Dynamic Content**: No way to customize ticket content based on project characteristics
- **Keyword Substitution**: No template system for inserting computed values into tickets
- **Batch Operations**: No way to distribute organizational changes across all relevant projects

## Intended Behavior

Create a dynamic ticket distribution system that:

### Core Functionality
1. **Template Processing**: Takes an input ticket file with keyword placeholders
2. **Project Distribution**: Creates copies in each project directory's issues folder
3. **Dynamic Data Insertion**: Replaces keyword placeholders with project-specific statistics
4. **Configurable Keywords**: User-defined keyword functions that execute bash commands
5. **Auto-Statistics**: Gathers relevant project metrics without external dependencies

### Markup Language Features
- **Keyword Syntax**: `][variable_name[]` placeholders in template files
- **Bash Execution**: Each keyword maps to configurable bash command
- **Context Awareness**: Commands can access current project directory context
- **No External Dependencies**: Works without LLM calls unless Ollama is specifically running
- **Extensible Configuration**: Easy addition of new keyword functions via config files

## BREAKDOWN NOTICE

**This issue has been broken down into 7 individual implementation issues:**

- **Issue 016**: Design Keyword Markup Language
- **Issue 017**: Implement Keyword Processing Engine  
- **Issue 018**: Create Project Discovery System
- **Issue 019**: Implement Ticket Distribution Engine
- **Issue 020**: Create Interactive Interface
- **Issue 021**: Implement Validation and Testing System
- **Issue 022**: Create Integration and Workflow System

**Recommended Implementation Order:**
1. Issue 016 (Design Keyword Markup Language)
2. Issue 017 (Implement Keyword Processing Engine)
3. Issue 018 (Create Project Discovery System)
4. Issue 019 (Implement Ticket Distribution Engine)
5. Issue 020 (Create Interactive Interface)
6. Issue 021 (Implement Validation and Testing System)
7. Issue 022 (Create Integration and Workflow System)

## Original Implementation Steps (Reference)

### 1. Script Architecture → Issue 022
### 2. Configuration System Design → Issue 016, 017
### 3. Core Keyword Functions → Issue 016, 017
### 4. Template Processing Engine → Issue 017
### 5. Project Discovery and Filtering → Issue 018
### 6. Distribution Mechanism → Issue 019
### 7. Safety and Validation → Issue 021

## Implementation Details

### Script Structure
```bash
#!/bin/bash
# Set hardcoded directory path
DIR="${1:-/home/ritz/programming/ai-stuff}"

# -- {{{ main
function main() {
    # Main distribution logic
}
# }}}

# -- {{{ process_template
function process_template() {
    # Template keyword processing
}
# }}}

# -- {{{ execute_keyword
function execute_keyword() {
    # Execute bash command for keyword
}
# }}}
```

### Configuration File Format
```ini
# ticket-keywords.conf
[keywords]
project_name="basename $(pwd)"
file_count="find . -type f | wc -l"
src_files="find ./src -name '*.lua' -o -name '*.c' -o -name '*.rs' | wc -l 2>/dev/null || echo 0"
function_usage="grep -r 'FUNCTION_NAME' --include='*.lua' --include='*.c' ./src/ | wc -l 2>/dev/null || echo 0"
```

### Interactive Mode Features
- `-I` flag for interactive execution
- Project selection (with index-based navigation)
- Keyword preview and confirmation
- Template content review before distribution

### Integration Points
- Works with existing issue tracking structure from CLAUDE.md conventions
- Integrates with git repository system (Issues 001, 002)
- Supports project-specific documentation requirements
- Compatible with phase-based development workflow

## Use Cases

### Dependency Update Notifications
Template: "Please evaluate updating [library_name] dependency"
Keywords: `][current_version[]`, `][usage_count[]`, `][affected_files[]`

### Code Style Changes
Template: "Migrate to new comment style standard"  
Keywords: `][current_comment_style[]`, `][files_needing_update[]`, `][estimated_changes[]`

### Meta-Project Organization
Template: "Implement new directory structure standard"
Keywords: `][current_structure[]`, `][size_impact[]`, `][migration_complexity[]`

### Shared Function Updates
Template: "Function [function_name] has new interface"
Keywords: `][function_usage[function_name][]`, `][affected_modules[]`

## Related Documents
- `001-comprehensive-git-repository-setup.md` - Repository structure for ticket distribution
- `002-gitignore-unification-script.md` - Example of cross-project coordination needs
- `/home/ritz/.claude/CLAUDE.md` - Issue tracking conventions and requirements

## Tools Required
- Bash scripting with text processing (sed, awk, grep)
- Configuration file parsing
- File system traversal and manipulation
- Git integration for project discovery
- Template processing capabilities

## Metadata
- **Priority**: Medium-High
- **Complexity**: Advanced
- **Estimated Time**: 3-4 hours
- **Dependencies**: Issue 001 (for proper issue directory structure)
- **Impact**: Cross-project communication, organizational efficiency

## Success Criteria
- Template ticket can be distributed to all relevant projects
- Keywords are correctly substituted with project-specific data
- New keyword functions can be easily added via configuration
- Interactive mode allows selective distribution
- No external dependencies required (works offline)
- Integration with existing issue tracking conventions