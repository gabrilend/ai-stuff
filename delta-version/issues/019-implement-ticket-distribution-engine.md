# Issue 019: Implement Ticket Distribution Engine

## Current Behavior

The project discovery system can identify target projects (Issue 018), and the keyword processing engine can process templates (Issue 017), but there is no system to actually distribute processed tickets to project directories. Each project needs to receive customized tickets in their appropriate issue tracking structure.

## Intended Behavior

Create a comprehensive ticket distribution engine that:
1. **Issue Directory Management**: Create/maintain proper issue tracking structure in each project
2. **Sequential Numbering**: Assign appropriate issue numbers within each project's sequence
3. **Batch Distribution**: Process and distribute tickets to multiple projects efficiently
4. **Conflict Resolution**: Handle cases where tickets already exist or directories are missing
5. **Distribution Tracking**: Record which projects received which tickets for future reference

## Suggested Implementation Steps

### 1. Issue Directory Structure Management
```bash
# -- {{{ ensure_issue_structure
function ensure_issue_structure() {
    local project_dir="$1"
    
    # Create issue tracking structure following CLAUDE.md conventions:
    # project/issues/phase-1/
    # project/issues/completed/
    # project/issues/phase-1/progress.md (if doesn't exist)
}
# }}}
```

### 2. Issue Number Management
```bash
# -- {{{ get_next_issue_number
function get_next_issue_number() {
    local project_dir="$1"
    local phase="$2"
    
    # Scan existing issues in project's phase directory
    # Find highest issue number (XXX-description.md format)
    # Return next sequential number
    # Handle gaps in numbering gracefully
}
# }}}
```

### 3. Ticket Processing and Customization
```bash
# -- {{{ process_ticket_for_project
function process_ticket_for_project() {
    local template_file="$1"
    local project_dir="$2"
    local keyword_config="$3"
    
    # Process template with project-specific keyword substitution
    # Generate project-customized ticket content
    # Preserve template structure and formatting
    # Handle any processing errors gracefully
}
# }}}
```

### 4. Distribution Engine Core
```bash
# -- {{{ distribute_ticket_to_projects
function distribute_ticket_to_projects() {
    local template_file="$1"
    local target_projects="$2"
    local distribution_options="$3"
    
    # For each target project:
    # 1. Ensure proper issue directory structure
    # 2. Process template with project-specific data
    # 3. Assign appropriate issue number
    # 4. Write customized ticket to project directory
    # 5. Update distribution tracking
}
# }}}
```

### 5. Conflict and Error Handling
```bash
# -- {{{ handle_distribution_conflicts
function handle_distribution_conflicts() {
    local project_dir="$1"
    local issue_number="$2"
    local conflict_resolution="$3"
    
    # Handle cases where issue number already exists
    # Manage missing or inaccessible directories
    # Deal with permission or disk space issues
    # Provide clear error reporting and recovery options
}
# }}}
```

### 6. Distribution Tracking and Reporting
```bash
# -- {{{ track_distribution
function track_distribution() {
    local template_file="$1"
    local distributed_projects="$2"
    local distribution_id="$3"
    
    # Record distribution event in tracking database
    # Log which projects received which tickets
    # Track template versions and customizations
    # Enable future rollback or update operations
}
# }}}
```

## Implementation Details

### Issue Directory Structure Creation
```bash
# -- {{{ create_project_issue_structure
function create_project_issue_structure() {
    local project_dir="$1"
    
    # Create directory structure
    mkdir -p "$project_dir/issues/phase-1"
    mkdir -p "$project_dir/issues/completed"
    
    # Create progress.md if it doesn't exist
    if [[ ! -f "$project_dir/issues/phase-1/progress.md" ]]; then
        cat > "$project_dir/issues/phase-1/progress.md" <<EOF
# Phase 1 Progress

## Overview
This document tracks the progress of Phase 1 issues for the $(basename "$project_dir") project.

## Completed Issues
- None yet

## In Progress
- None yet

## Pending
- All issues

## Notes
- Progress tracking follows CLAUDE.md conventions
- Issues are automatically distributed via ticket distribution system
EOF
    fi
}
# }}}
```

### Issue Number Assignment Logic
```bash
# -- {{{ assign_issue_number
function assign_issue_number() {
    local project_dir="$1"
    local phase_dir="$project_dir/issues/phase-1"
    
    # Find existing issue files
    local max_number=0
    
    if [[ -d "$phase_dir" ]]; then
        for file in "$phase_dir"/*.md; do
            [[ -f "$file" ]] || continue
            
            # Extract number from XXX-description.md format
            local filename=$(basename "$file")
            if [[ "$filename" =~ ^([0-9]+)-.*\.md$ ]]; then
                local num="${BASH_REMATCH[1]}"
                # Remove leading zeros and compare
                num=$((10#$num))
                if [[ $num -gt $max_number ]]; then
                    max_number=$num
                fi
            fi
        done
    fi
    
    # Return next number with zero padding
    printf "%03d" $((max_number + 1))
}
# }}}
```

### Distribution Batch Processing
```bash
# -- {{{ batch_distribute_tickets
function batch_distribute_tickets() {
    local template_file="$1"
    local target_projects=("${@:2}")
    
    local distribution_id="dist_$(date +%Y%m%d_%H%M%S)"
    local success_count=0
    local error_count=0
    
    echo "Starting batch distribution: $distribution_id"
    echo "Template: $(basename "$template_file")"
    echo "Target projects: ${#target_projects[@]}"
    
    for project in "${target_projects[@]}"; do
        echo -n "Processing $(basename "$project")..."
        
        if distribute_to_single_project "$template_file" "$project" "$distribution_id"; then
            echo " ✓"
            ((success_count++))
        else
            echo " ✗"
            ((error_count++))
        fi
    done
    
    echo "Distribution complete: $success_count success, $error_count errors"
    
    # Record distribution summary
    record_distribution_summary "$distribution_id" "$template_file" "$success_count" "$error_count"
}
# }}}
```

### Single Project Distribution
```bash
# -- {{{ distribute_to_single_project
function distribute_to_single_project() {
    local template_file="$1"
    local project_dir="$2"
    local distribution_id="$3"
    
    # Ensure issue structure exists
    create_project_issue_structure "$project_dir" || return 1
    
    # Get next issue number
    local issue_num
    issue_num=$(assign_issue_number "$project_dir") || return 1
    
    # Process template with project-specific data
    local processed_content
    processed_content=$(process_template_file "$template_file" "$project_dir" "$KEYWORD_CONFIG") || return 1
    
    # Generate filename from template
    local template_basename=$(basename "$template_file" .md)
    local issue_filename="${issue_num}-${template_basename}.md"
    local output_path="$project_dir/issues/phase-1/$issue_filename"
    
    # Write processed ticket
    echo "$processed_content" > "$output_path" || return 1
    
    # Track distribution
    record_project_distribution "$project_dir" "$issue_filename" "$distribution_id"
    
    return 0
}
# }}}
```

### Distribution Tracking Database
```bash
# Distribution tracking in .ticket_distribution_log
# Format: timestamp|distribution_id|project|issue_file|template|status
function record_project_distribution() {
    local project_dir="$1"
    local issue_file="$2"
    local distribution_id="$3"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local project_name=$(basename "$project_dir")
    
    echo "$timestamp|$distribution_id|$project_name|$issue_file|$CURRENT_TEMPLATE|success" \
        >> "$BASE_DIR/.ticket_distribution_log"
}
```

### Error Recovery and Rollback
```bash
# -- {{{ rollback_distribution
function rollback_distribution() {
    local distribution_id="$1"
    
    echo "Rolling back distribution: $distribution_id"
    
    # Find all files created in this distribution
    grep "$distribution_id" "$BASE_DIR/.ticket_distribution_log" | \
    while IFS='|' read -r timestamp dist_id project issue_file template status; do
        if [[ "$status" == "success" ]]; then
            local file_path="$BASE_DIR/$project/issues/phase-1/$issue_file"
            if [[ -f "$file_path" ]]; then
                rm "$file_path"
                echo "Removed: $project/$issue_file"
            fi
        fi
    done
    
    # Mark distribution as rolled back
    echo "$(date '+%Y-%m-%d %H:%M:%S')|$distribution_id|SYSTEM|ROLLBACK|SYSTEM|rollback" \
        >> "$BASE_DIR/.ticket_distribution_log"
}
# }}}
```

## Related Documents
- `018-create-project-discovery-system.md` - Provides target projects
- `017-implement-keyword-processing-engine.md` - Processes templates
- `020-create-interactive-interface.md` - Uses distribution engine
- `003-dynamic-ticket-distribution-system.md` - Parent ticket

## Tools Required
- File system manipulation and I/O
- Directory structure management
- Template processing integration
- Batch processing capabilities
- Error handling and logging
- Distribution tracking database

## Metadata
- **Priority**: High
- **Complexity**: High
- **Estimated Time**: 2-2.5 hours
- **Dependencies**: Issues 017, 018 (processing engine, project discovery)
- **Impact**: Core functionality of ticket distribution system

## Success Criteria
- Tickets distributed to all target projects successfully
- Proper issue tracking structure created in each project
- Sequential issue numbering maintained per project
- Project-specific data correctly substituted in templates
- Error handling prevents partial failures
- Distribution tracking enables future maintenance
- Batch processing handles multiple projects efficiently
- Rollback capability available for emergency situations