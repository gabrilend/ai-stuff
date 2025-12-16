# Issue 020: Create Interactive Interface

## Current Behavior

The ticket distribution engine can distribute tickets (Issue 019), but there is no user-friendly interface for operating the system. Users must manually call individual functions or scripts, and there's no guided workflow for common operations like creating and distributing tickets.

## Intended Behavior

Create a comprehensive interactive interface that:
1. **Guided Workflows**: Step-by-step guidance for common operations
2. **Template Management**: Interface for creating, editing, and managing ticket templates
3. **Project Selection**: Interactive project discovery and filtering
4. **Preview Capabilities**: Preview processed tickets before distribution
5. **Distribution Control**: Fine-grained control over distribution options

## Suggested Implementation Steps

### 1. Main Interactive Menu System
```bash
# -- {{{ interactive_main_menu
function interactive_main_menu() {
    echo "=== Dynamic Ticket Distribution System ==="
    echo "1. Create new ticket template"
    echo "2. Distribute existing template"
    echo "3. Preview ticket processing"
    echo "4. Manage project discovery"
    echo "5. View distribution history"
    echo "6. System configuration"
    echo "7. Help and documentation"
    echo "q. Quit"
    
    read -p "Select option [1-7,q]: " choice
    handle_main_menu_choice "$choice"
}
# }}}
```

### 2. Template Creation Wizard
```bash
# -- {{{ template_creation_wizard
function template_creation_wizard() {
    echo "=== Ticket Template Creation Wizard ==="
    
    # Step 1: Basic template information
    read -p "Template name: " template_name
    read -p "Template description: " template_desc
    
    # Step 2: Target project type selection
    echo "Target project types:"
    echo "1. All projects"
    echo "2. Specific language (lua, rust, c)"
    echo "3. Custom filter"
    
    # Step 3: Template content creation
    create_template_content "$template_name" "$template_desc"
    
    # Step 4: Keyword insertion assistance
    offer_keyword_insertion
    
    # Step 5: Template validation and preview
    validate_and_preview_template
}
# }}}
```

### 3. Project Selection Interface
```bash
# -- {{{ interactive_project_selection
function interactive_project_selection() {
    echo "=== Project Selection ==="
    
    # Discover projects
    local projects
    projects=$(discover_project_directories "$BASE_DIR")
    
    # Display project list with relevance scores
    echo "Available projects:"
    local i=1
    while IFS= read -r project; do
        local score=$(calculate_project_relevance "$project" "$TICKET_TYPE")
        local lang=$(classify_project_language "$project")
        printf "%2d. %-25s (Score: %3d, Lang: %s)\n" "$i" "$(basename "$project")" "$score" "$lang"
        ((i++))
    done <<< "$projects"
    
    echo "Selection options:"
    echo "a. Select all projects"
    echo "f. Filter by criteria"
    echo "s. Select specific projects"
    echo "c. Custom selection"
    
    read -p "Choose selection method [a/f/s/c]: " selection_method
    handle_project_selection "$selection_method" "$projects"
}
# }}}
```

### 4. Preview and Confirmation System
```bash
# -- {{{ preview_ticket_distribution
function preview_ticket_distribution() {
    local template_file="$1"
    local target_projects=("${@:2}")
    
    echo "=== Distribution Preview ==="
    echo "Template: $(basename "$template_file")"
    echo "Target projects: ${#target_projects[@]}"
    echo ""
    
    # Show preview for first few projects
    local preview_count=0
    for project in "${target_projects[@]}"; do
        if [[ $preview_count -ge 3 ]]; then
            echo "... and $((${#target_projects[@]} - 3)) more projects"
            break
        fi
        
        echo "--- Preview for $(basename "$project") ---"
        local processed_content
        processed_content=$(process_template_file "$template_file" "$project" "$KEYWORD_CONFIG")
        echo "$processed_content" | head -15
        echo ""
        
        ((preview_count++))
    done
    
    echo "Proceed with distribution? [y/N]"
    read -p "> " confirm
    [[ "$confirm" =~ ^[Yy] ]] && return 0 || return 1
}
# }}}
```

### 5. Configuration Management Interface
```bash
# -- {{{ interactive_configuration
function interactive_configuration() {
    echo "=== System Configuration ==="
    echo "1. Keyword definitions"
    echo "2. Project discovery settings"
    echo "3. Distribution options"
    echo "4. Error handling preferences"
    echo "5. Template directories"
    echo "6. Reset to defaults"
    
    read -p "Configure what? [1-6]: " config_choice
    
    case "$config_choice" in
        1) configure_keywords_interactive ;;
        2) configure_discovery_interactive ;;
        3) configure_distribution_interactive ;;
        4) configure_error_handling_interactive ;;
        5) configure_template_paths_interactive ;;
        6) reset_configuration_interactive ;;
    esac
}
# }}}
```

### 6. Help and Documentation System
```bash
# -- {{{ show_interactive_help
function show_interactive_help() {
    echo "=== Help and Documentation ==="
    echo "1. Getting started guide"
    echo "2. Template creation tutorial"
    echo "3. Keyword reference"
    echo "4. Project discovery explained"
    echo "5. Distribution options"
    echo "6. Troubleshooting guide"
    echo "7. Example templates"
    
    read -p "Show help for? [1-7]: " help_choice
    
    case "$help_choice" in
        1) show_getting_started_guide ;;
        2) show_template_tutorial ;;
        3) show_keyword_reference ;;
        4) show_discovery_guide ;;
        5) show_distribution_options ;;
        6) show_troubleshooting ;;
        7) show_example_templates ;;
    esac
}
# }}}
```

## Implementation Details

### Index-Based Navigation System
```bash
# -- {{{ handle_indexed_selection
function handle_indexed_selection() {
    local options=("$@")
    local selection_prompt="$1"
    
    # Display options with indices
    for i in "${!options[@]}"; do
        echo "$((i+1)). ${options[$i]}"
    done
    
    # Handle user input (index, range, or vim-style)
    read -p "$selection_prompt: " user_input
    
    case "$user_input" in
        [0-9]*) handle_numeric_selection "$user_input" "${options[@]}" ;;
        *-*) handle_range_selection "$user_input" "${options[@]}" ;;
        [iI]) handle_vim_selection "${options[@]}" ;;
        *) echo "Invalid selection: $user_input" ;;
    esac
}
# }}}
```

### Template Content Editor Integration
```bash
# -- {{{ edit_template_content
function edit_template_content() {
    local template_file="$1"
    
    # Check for available editors
    if command -v "$EDITOR" > /dev/null; then
        "$EDITOR" "$template_file"
    elif command -v vim > /dev/null; then
        vim "$template_file"
    elif command -v nano > /dev/null; then
        nano "$template_file"
    else
        echo "No suitable editor found. Please edit manually: $template_file"
        return 1
    fi
    
    # Validate template after editing
    validate_template_syntax "$template_file"
}
# }}}
```

### Keyword Insertion Assistant
```bash
# -- {{{ offer_keyword_insertion
function offer_keyword_insertion() {
    echo "Would you like to add dynamic keywords to your template? [y/N]"
    read -p "> " add_keywords
    
    if [[ "$add_keywords" =~ ^[Yy] ]]; then
        echo "Available keyword categories:"
        echo "1. Project information (][project_name[], ][file_count[])"
        echo "2. Statistics (][size_stats[], ][commit_count[])"
        echo "3. Analysis (][function_usage[name][], ][dependency_list[])"
        echo "4. Meta information (][current_date[], ][generation_time[])"
        
        read -p "Insert keywords from which category? [1-4]: " keyword_cat
        insert_keywords_by_category "$keyword_cat"
    fi
}
# }}}
```

### Distribution History Viewer
```bash
# -- {{{ view_distribution_history
function view_distribution_history() {
    echo "=== Distribution History ==="
    
    if [[ ! -f "$BASE_DIR/.ticket_distribution_log" ]]; then
        echo "No distribution history found."
        return
    fi
    
    echo "Recent distributions:"
    tail -20 "$BASE_DIR/.ticket_distribution_log" | \
    while IFS='|' read -r timestamp dist_id project issue_file template status; do
        printf "%-19s | %-12s | %-15s | %s\n" "$timestamp" "$dist_id" "$project" "$status"
    done
    
    echo ""
    echo "Options:"
    echo "1. View specific distribution details"
    echo "2. Rollback distribution"
    echo "3. Export history report"
    
    read -p "Action [1-3]: " history_action
    handle_history_action "$history_action"
}
# }}}
```

### Error-Friendly User Experience
```bash
# -- {{{ user_friendly_error_handling
function user_friendly_error_handling() {
    local error_msg="$1"
    local context="$2"
    
    case "$context" in
        "template_not_found")
            echo "Error: Template file not found."
            echo "Suggestion: Use option 1 to create a new template, or check the file path."
            ;;
        "no_projects_found")
            echo "Error: No suitable projects found for distribution."
            echo "Suggestion: Check project discovery settings or create a custom filter."
            ;;
        "keyword_processing_failed")
            echo "Error: Failed to process template keywords."
            echo "Suggestion: Check keyword syntax and configuration file."
            ;;
        *)
            echo "Error: $error_msg"
            echo "See troubleshooting guide (option 7 > 6) for more help."
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}
# }}}
```

## Related Documents
- `019-implement-ticket-distribution-engine.md` - Core functionality used by interface
- `021-implement-validation-and-testing-system.md` - Validation integrated into interface
- `003-dynamic-ticket-distribution-system.md` - Parent ticket

## Tools Required
- Interactive menu systems and user input handling
- Text editor integration
- File management utilities
- Configuration file manipulation
- Progress indicators and feedback systems

## Metadata
- **Priority**: Medium-High
- **Complexity**: Medium
- **Estimated Time**: 2-2.5 hours
- **Dependencies**: Issue 019 (distribution engine)
- **Impact**: User experience and system usability

## Success Criteria
- Intuitive menu system guides users through common operations
- Template creation wizard simplifies template development
- Project selection interface provides clear project overview
- Preview system prevents unwanted distributions
- Configuration management accessible to non-technical users
- Help system provides comprehensive guidance
- Error handling provides clear, actionable guidance
- Interface follows CLAUDE.md conventions for interaction modes