# Issue 022: Create Integration and Workflow System

## Current Behavior

All components of the dynamic ticket distribution system have been implemented and tested (Issues 016-021), but they exist as separate utilities without integration into the overall development workflow. There is no cohesive user experience, automated triggers, or integration with the git repository management system.

## Intended Behavior

Create seamless integration and workflow system that:
1. **Master Script Interface**: Single command-line tool with all functionality
2. **Git Integration**: Automatic triggers during repository operations
3. **Development Workflow**: Integration with project lifecycle and issue management
4. **Configuration Management**: Centralized configuration with environment detection
5. **Documentation Integration**: Complete user guides and workflow documentation

## Suggested Implementation Steps

### 1. Master Script Creation
```bash
#!/bin/bash
# scripts/distribute-tickets.sh
DIR="${1:-/home/ritz/programming/ai-stuff}"

# -- {{{ main
function main() {
    parse_arguments "$@"
    load_configuration
    execute_requested_action
}
# }}}
```

### 2. Unified Command Line Interface
```bash
# -- {{{ parse_arguments
function parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -I|--interactive)
                MODE="interactive"
                shift
                ;;
            --template)
                TEMPLATE_FILE="$2"
                shift 2
                ;;
            --create-template)
                ACTION="create_template"
                TEMPLATE_NAME="$2"
                shift 2
                ;;
            --distribute)
                ACTION="distribute"
                shift
                ;;
            --preview)
                ACTION="preview"
                shift
                ;;
            --projects)
                FILTER_PROJECTS="$2"
                shift 2
                ;;
            --validate)
                ACTION="validate"
                shift
                ;;
            --test)
                ACTION="test"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}
# }}}
```

### 3. Integration with Git Repository System
```bash
# -- {{{ integrate_with_git_workflow
function integrate_with_git_workflow() {
    # Integration points with Issues 001, 006 (git repository setup)
    
    # Called during repository initialization
    if [[ "$1" == "--init-repository" ]]; then
        setup_ticket_distribution_for_repo
    fi
    
    # Called during project branch management
    if [[ "$1" == "--branch-setup" ]]; then
        configure_branch_specific_tickets
    fi
    
    # Called during maintenance operations
    if [[ "$1" == "--maintenance" ]]; then
        run_scheduled_ticket_maintenance
    fi
}
# }}}
```

### 4. Development Workflow Integration
```bash
# -- {{{ integrate_with_development_lifecycle
function integrate_with_development_lifecycle() {
    # Integration with CLAUDE.md conventions
    
    # Phase completion triggers
    if [[ "$1" == "--phase-complete" ]]; then
        distribute_phase_completion_notifications
    fi
    
    # New project creation
    if [[ "$1" == "--new-project" ]]; then
        setup_project_ticket_structure
    fi
    
    # Cross-project updates
    if [[ "$1" == "--cross-project-update" ]]; then
        handle_cross_project_distribution
    fi
}
# }}}
```

### 5. Configuration Management System
```bash
# -- {{{ load_unified_configuration
function load_unified_configuration() {
    # Load configurations in priority order:
    # 1. Project-specific config
    # 2. User-specific config  
    # 3. System defaults
    
    local config_files=(
        "$DIR/.ticket-distribution.conf"
        "$HOME/.ticket-distribution.conf"
        "$SCRIPT_DIR/config/defaults.conf"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            load_config_file "$config_file"
        fi
    done
}
# }}}
```

### 6. Workflow Documentation and Help System
```bash
# -- {{{ show_comprehensive_help
function show_comprehensive_help() {
    cat <<EOF
DYNAMIC TICKET DISTRIBUTION SYSTEM
==================================

OVERVIEW:
  This system automates the distribution of tickets across multiple projects
  with dynamic, project-specific content substitution.

USAGE:
  $0 [OPTIONS] [DIRECTORY]

COMMON WORKFLOWS:

  1. Create and distribute a new ticket:
     $0 --create-template dependency-update
     $0 --template templates/dependency-update.md --distribute

  2. Preview distribution before executing:
     $0 --template templates/code-style.md --preview --projects lua,rust

  3. Interactive mode for guided workflows:
     $0 --interactive

  4. Validate system configuration:
     $0 --validate --test

INTEGRATION:
  - Integrates with git repository setup (Issues 001, 006)
  - Follows CLAUDE.md conventions for project structure
  - Supports automated triggers during development workflows

EXAMPLES:
  # Distribute dependency update to all Rust projects
  $0 --template templates/dependency-update.md --projects rust --distribute

  # Create new code style ticket template
  $0 --create-template code-style-migration --interactive

  # Test system with current configuration
  $0 --validate --test

For detailed documentation: docs/ticket-distribution-guide.md
EOF
}
# }}}
```

## Implementation Details

### Master Script Architecture
```bash
#!/bin/bash
# scripts/distribute-tickets.sh
# Master interface for dynamic ticket distribution system
DIR="${1:-/home/ritz/programming/ai-stuff}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source component modules
source "$SCRIPT_DIR/lib/keyword-processing.sh"
source "$SCRIPT_DIR/lib/project-discovery.sh"
source "$SCRIPT_DIR/lib/distribution-engine.sh"
source "$SCRIPT_DIR/lib/interactive-interface.sh"
source "$SCRIPT_DIR/lib/validation-testing.sh"

# Configuration and state
declare -A CONFIG
declare -A KEYWORD_COMMANDS
declare -a TARGET_PROJECTS

# -- {{{ main
function main() {
    # Main execution flow
    initialize_system
    parse_arguments "$@"
    load_configuration
    execute_requested_action
}
# }}}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### Component Module Organization
```
scripts/
├── distribute-tickets.sh (master script)
├── lib/
│   ├── keyword-processing.sh (Issues 016-017)
│   ├── project-discovery.sh (Issue 018)
│   ├── distribution-engine.sh (Issue 019)
│   ├── interactive-interface.sh (Issue 020)
│   └── validation-testing.sh (Issue 021)
├── config/
│   ├── defaults.conf
│   ├── keyword-definitions.conf
│   └── project-discovery.conf
└── templates/
    ├── dependency-update.md
    ├── code-style-change.md
    └── cross-project-announcement.md
```

### Git Repository Integration
```bash
# Integration with git repository setup process
function setup_ticket_distribution_for_repo() {
    local repo_dir="$1"
    
    # Create ticket distribution directory structure
    mkdir -p "$repo_dir/scripts/lib"
    mkdir -p "$repo_dir/scripts/config"
    mkdir -p "$repo_dir/scripts/templates"
    
    # Install default configuration
    cp "$SCRIPT_DIR/config/defaults.conf" "$repo_dir/scripts/config/"
    cp "$SCRIPT_DIR/config/keyword-definitions.conf" "$repo_dir/scripts/config/"
    
    # Create repository-specific configuration
    cat > "$repo_dir/.ticket-distribution.conf" <<EOF
# Ticket distribution configuration for $(basename "$repo_dir")
[general]
base_directory=$repo_dir
template_directory=$repo_dir/scripts/templates
config_directory=$repo_dir/scripts/config

[discovery]
exclude_libraries=true
min_project_size=5
include_patterns=src/,docs/,issues/

[distribution]
auto_assign_numbers=true
backup_before_distribution=true
confirm_before_distribute=true
EOF
}
```

### Development Lifecycle Integration
```bash
# Integration with CLAUDE.md workflow conventions
function handle_phase_completion() {
    local project_dir="$1"
    local completed_phase="$2"
    
    # Create phase completion announcement template
    local template="$DIR/scripts/templates/phase-completion.md"
    
    if [[ ! -f "$template" ]]; then
        create_phase_completion_template "$template" "$completed_phase"
    fi
    
    # Distribute to relevant projects
    local related_projects
    related_projects=$(find_projects_with_shared_dependencies "$project_dir")
    
    if [[ -n "$related_projects" ]]; then
        distribute_ticket_to_projects "$template" $related_projects
    fi
}
```

### Automated Trigger System
```bash
# Git hooks integration
function setup_git_integration() {
    local repo_dir="$1"
    
    # Post-commit hook for automatic ticket updates
    cat > "$repo_dir/.git/hooks/post-commit" <<'EOF'
#!/bin/bash
# Check if any ticket templates have been modified
if git diff --name-only HEAD~1 HEAD | grep -q "scripts/templates/"; then
    echo "Ticket templates modified, checking for redistribution..."
    ./scripts/distribute-tickets.sh --validate --auto-update
fi
EOF
    
    chmod +x "$repo_dir/.git/hooks/post-commit"
}
```

### User Experience Enhancements
```bash
# -- {{{ provide_contextual_help
function provide_contextual_help() {
    local context="$1"
    
    case "$context" in
        "first_run")
            echo "Welcome to the Dynamic Ticket Distribution System!"
            echo "Run '$0 --interactive' for a guided setup."
            ;;
        "no_templates")
            echo "No templates found. Create one with:"
            echo "  $0 --create-template template-name"
            ;;
        "no_projects")
            echo "No projects found for distribution."
            echo "Check project discovery settings with '$0 --validate'"
            ;;
    esac
}
# }}}
```

### Configuration Migration and Upgrades
```bash
# -- {{{ handle_configuration_migration
function handle_configuration_migration() {
    local config_version
    config_version=$(get_config_version)
    
    if [[ "$config_version" != "$CURRENT_VERSION" ]]; then
        echo "Migrating configuration from v$config_version to v$CURRENT_VERSION"
        migrate_configuration_format "$config_version" "$CURRENT_VERSION"
    fi
}
# }}}
```

## Related Documents
- Issues 016-021 - All component implementations
- `001-prepare-repository-structure.md` - Git repository integration
- `006-initialize-master-branch.md` - Repository setup integration
- `003-dynamic-ticket-distribution-system.md` - Parent ticket

## Tools Required
- Master script development and testing
- Git hook integration
- Configuration management systems
- Documentation generation
- Workflow automation tools

## Metadata
- **Priority**: Medium-High
- **Complexity**: Medium
- **Estimated Time**: 2-3 hours
- **Dependencies**: Issues 016-021 (all system components)
- **Impact**: User experience, system integration, workflow automation

## Success Criteria
- Single master script provides access to all functionality
- Command-line interface supports both interactive and headless modes
- Git repository integration works seamlessly with existing workflows
- Configuration management handles various deployment scenarios
- Documentation provides comprehensive usage guidance
- Integration with CLAUDE.md conventions maintained throughout
- System ready for production deployment across all projects
- Automated triggers reduce manual maintenance overhead