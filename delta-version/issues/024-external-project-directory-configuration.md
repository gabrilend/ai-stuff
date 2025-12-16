# Issue 024: External Project Directory Configuration

## Current Behavior

The Delta-Version project listing utility and related systems are hardcoded to search only within the `/home/ritz/programming/ai-stuff/` directory. This limits the system to managing projects that exist within this single directory structure, preventing integration with projects stored in other locations on the filesystem.

### Current Limitations
- Project discovery limited to single base directory
- No mechanism to include external project directories
- Scripts hardcode the base directory path
- No configuration system for external project sources
- Documentation doesn't address external project scenarios
- Cross-directory project management not supported

## Intended Behavior

Create a flexible configuration system that allows:
1. **External Directory Registration**: Define additional project source directories outside the main repository
2. **Unified Project Discovery**: Seamlessly integrate external projects with main repository projects
3. **Configuration Management**: Centralized config file for external directory definitions
4. **Documentation Integration**: Updated documentation explaining external project workflows
5. **Backward Compatibility**: Maintain existing functionality while adding external support

## Suggested Implementation Steps

### 1. Create External Projects Configuration File
```ini
# config/external-projects.conf
[external_directories]
# Additional directories to search for projects
# Format: name=path
personal_projects=/home/ritz/personal-projects
work_projects=/opt/work/development
legacy_code=/mnt/backup/old-projects

[external_project_settings]
# How to handle external projects
include_in_listings=true
enable_cross_directory_operations=false
validate_external_paths=true
```

### 2. Update Project Listing Utility Integration
```bash
# -- {{{ load_external_directories
function load_external_directories() {
    local config_file="$DIR/delta-version/config/external-projects.conf"
    
    if [[ -f "$config_file" ]]; then
        # Parse configuration and return external directories
        grep -E "^[^#].*=" "$config_file" | grep -v "^\[" | while IFS='=' read -r name path; do
            if [[ -d "$path" ]]; then
                echo "$path"
            else
                echo "Warning: External directory '$path' not found" >&2
            fi
        done
    fi
}
# }}}
```

### 3. Enhanced Project Discovery Function
```bash
# -- {{{ get_all_project_directories
function get_all_project_directories() {
    local output_format="${1:-names}"
    local include_external="${2:-true}"
    
    # Get main repository projects
    local main_projects
    readarray -t main_projects < <(get_project_list_for_integration "$output_format" "$DIR")
    
    # Get external projects if enabled
    if [[ "$include_external" == "true" ]]; then
        while IFS= read -r external_dir; do
            [[ -z "$external_dir" ]] && continue
            readarray -t -O "${#main_projects[@]}" main_projects < <(get_project_list_for_integration "$output_format" "$external_dir")
        done < <(load_external_directories)
    fi
    
    printf '%s\n' "${main_projects[@]}"
}
# }}}
```

### 4. Configuration Management Functions
```bash
# -- {{{ add_external_directory
function add_external_directory() {
    local name="$1"
    local path="$2"
    local config_file="$DIR/delta-version/config/external-projects.conf"
    
    # Validate directory exists
    if [[ ! -d "$path" ]]; then
        echo "Error: Directory '$path' does not exist" >&2
        return 1
    fi
    
    # Add to configuration
    echo "$name=$path" >> "$config_file"
    echo "Added external directory: $name -> $path"
}
# }}}

# -- {{{ remove_external_directory
function remove_external_directory() {
    local name="$1"
    local config_file="$DIR/delta-version/config/external-projects.conf"
    
    # Remove from configuration
    sed -i "/^$name=/d" "$config_file"
    echo "Removed external directory: $name"
}
# }}}

# -- {{{ list_external_directories
function list_external_directories() {
    local config_file="$DIR/delta-version/config/external-projects.conf"
    
    echo "=== EXTERNAL PROJECT DIRECTORIES ==="
    if [[ -f "$config_file" ]]; then
        grep -E "^[^#].*=" "$config_file" | grep -v "^\[" | while IFS='=' read -r name path; do
            if [[ -d "$path" ]]; then
                echo "  $name -> $path ✅"
            else
                echo "  $name -> $path ❌ (not found)"
            fi
        done
    else
        echo "  No external directories configured"
    fi
    echo
}
# }}}
```

### 5. Update list-projects.sh with External Support
```bash
# Enhanced command line options
#   --include-external   Include external project directories (default)
#   --exclude-external   Only search main repository directory
#   --external-only      Only search external directories
#   --manage-external    Interactive external directory management

# -- {{{ main function updates
function main() {
    local output_format="names"
    local base_directory="$DIR"
    local inverse_mode=false
    local include_external=true
    local external_only=false
    local manage_external=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --include-external)
                include_external=true
                shift
                ;;
            --exclude-external)
                include_external=false
                shift
                ;;
            --external-only)
                external_only=true
                include_external=true
                shift
                ;;
            --manage-external)
                manage_external=true
                shift
                ;;
            # ... existing options ...
        esac
    done
    
    if [[ "$manage_external" == "true" ]]; then
        run_external_management_mode
        exit 0
    fi
    
    if [[ "$external_only" == "true" ]]; then
        get_external_projects_only "$output_format"
    elif [[ "$inverse_mode" == "true" ]]; then
        get_non_project_directories "$output_format" "$base_directory"
    else
        get_all_project_directories "$output_format" "$include_external"
    fi
}
# }}}
```

### 6. External Directory Management Interface
```bash
# -- {{{ run_external_management_mode
function run_external_management_mode() {
    echo "=== External Project Directory Management ==="
    echo "1. List configured external directories"
    echo "2. Add external directory"
    echo "3. Remove external directory"
    echo "4. Validate external directories"
    echo "5. Test external project discovery"
    
    read -p "Select option [1-5]: " choice
    
    case $choice in
        1) list_external_directories ;;
        2) 
            read -p "Enter directory name: " name
            read -p "Enter directory path: " path
            add_external_directory "$name" "$path"
            ;;
        3)
            list_external_directories
            read -p "Enter directory name to remove: " name
            remove_external_directory "$name"
            ;;
        4) validate_external_directories ;;
        5) 
            echo "External projects discovered:"
            get_external_projects_only "abs-paths"
            ;;
        *) echo "Invalid selection" ;;
    esac
}
# }}}
```

### 7. Integration with Other Delta-Version Systems
```bash
# Update git branching system (Issue 005)
# Update ticket distribution system (Issues 018-022)
# Update gitignore analysis to include external projects
# Ensure all repository management scripts support external projects
```

## Implementation Tasks

### Task 1: Configuration Infrastructure
- [ ] Create `config/` directory in delta-version project
- [ ] Implement `config/external-projects.conf` with INI format
- [ ] Create configuration parsing functions
- [ ] Add validation for external directory paths
- [ ] Implement backup/restore functionality for configuration

### Task 2: Enhanced Project Listing Utility
- [ ] Update `list-projects.sh` with external directory support
- [ ] Add command line options for external directory control
- [ ] Implement external directory management interface
- [ ] Add external project discovery functions
- [ ] Update help documentation and usage examples

### Task 3: Integration with Existing Systems
- [ ] Update gitignore analysis script to include external projects
- [ ] Modify ticket distribution system for external project support
- [ ] Ensure git branching utilities work with external projects
- [ ] Update repository management scripts for cross-directory operations

### Task 4: Documentation Updates
- [ ] Update `docs/project-structure.md` with external directory information
- [ ] Create `docs/external-projects-guide.md` with setup instructions
- [ ] Update `docs/api-reference.md` with new configuration options
- [ ] Add external project examples to documentation
- [ ] Update `docs/table-of-contents.md` with new documentation files

### Task 5: Testing and Validation
- [ ] Create test scenarios for external directory functionality
- [ ] Validate backward compatibility with existing workflows
- [ ] Test error handling for missing external directories
- [ ] Verify integration with all existing Delta-Version utilities
- [ ] Create validation script for external project configuration

### Task 6: User Experience Enhancements
- [ ] Add interactive configuration wizard for first-time setup
- [ ] Implement configuration migration utilities
- [ ] Create external directory health checking
- [ ] Add status reporting for external project accessibility
- [ ] Provide clear error messages and troubleshooting guidance

## Configuration File Specification

### External Projects Configuration Format
```ini
# Delta-Version External Projects Configuration
# File: config/external-projects.conf

[external_directories]
# Format: symbolic_name=absolute_path
personal_dev=/home/ritz/personal-development
work_projects=/opt/company/projects
archived_code=/mnt/storage/archived-projects

[settings]
# Global settings for external project handling
include_in_default_listings=true
validate_paths_on_load=true
enable_cross_directory_git_operations=false
cache_external_discoveries=true
cache_duration_minutes=30

[path_validation]
# Path validation rules
require_absolute_paths=true
forbid_network_paths=true
check_read_permissions=true
warn_on_missing_directories=true

[integration]
# Integration with other Delta-Version systems
include_in_gitignore_analysis=true
include_in_ticket_distribution=true
include_in_branch_management=false
```

## Related Documents
- `023-create-project-listing-utility.md` - Core utility to be enhanced
- `009-discover-and-analyze-gitignore-files.md` - Should include external projects
- `018-create-project-discovery-system.md` - Ticket distribution integration
- `docs/project-structure.md` - Requires documentation updates

## Tools Required
- Configuration file parsing (INI format)
- File system path validation
- Interactive interface development
- Documentation generation tools
- Integration testing utilities

## Metadata
- **Priority**: Medium
- **Complexity**: Medium-High
- **Estimated Time**: 2-3 hours
- **Dependencies**: Issue 023 (Project Listing Utility)
- **Impact**: Enables multi-directory project management, expands system flexibility

## Success Criteria
- External directories can be configured via `config/external-projects.conf`
- Project listing utility seamlessly includes external projects
- Interactive management interface for external directory configuration
- All existing Delta-Version utilities work with external projects
- Comprehensive documentation for external project setup and usage
- Backward compatibility maintained with existing single-directory workflows
- Robust error handling and validation for external directory access
- Clear separation between main repository and external project operations

## Security Considerations
- Validate all external paths to prevent directory traversal attacks
- Ensure external directories have appropriate read permissions
- Prevent configuration of sensitive system directories
- Implement path sanitization for user-provided directory paths
- Log external directory access for audit purposes

## Future Enhancements
- Support for remote project directories (SSH, network mounts)
- Project synchronization between external and main directories
- Advanced filtering and classification of external projects
- Integration with version control systems in external directories
- Automated discovery of project directories in common locations