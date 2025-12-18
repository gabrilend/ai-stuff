# Issue 014: Create Maintenance Utilities

## Current Behavior

The unified `.gitignore` file has been created and validated (Issues 012-013), but there is no system for ongoing maintenance. When individual project `.gitignore` files change, or new projects are added, the unified file becomes outdated with no automated way to detect or address these changes.

## Intended Behavior

Create comprehensive maintenance utilities that:
1. **Change Detection**: Automatically detect when project `.gitignore` files have been modified
2. **Incremental Updates**: Update unified `.gitignore` without full regeneration when possible
3. **New Project Integration**: Add new projects to the unified system automatically
4. **Health Monitoring**: Regular checks to ensure unified patterns remain effective
5. **Maintenance Scheduling**: Integration with development workflows for regular updates

## Suggested Implementation Steps

### 1. Change Detection System
```bash
# -- {{{ detect_gitignore_changes
function detect_gitignore_changes() {
    local last_scan_file="$DIR/.gitignore_checksums"
    
    # Generate current checksums for all .gitignore files
    # Compare with previous scan results
    # Identify added, modified, or removed files
    # Report changes with timestamps and details
}
# }}}
```

### 2. Incremental Update Engine
```bash
# -- {{{ update_unified_incrementally
function update_unified_incrementally() {
    local changed_files="$1"
    
    # For minor changes: update only affected sections
    # For major changes: trigger full regeneration
    # Preserve manual customizations where possible
    # Validate changes before applying
}
# }}}
```

### 3. New Project Detection and Integration
```bash
# -- {{{ scan_for_new_projects
function scan_for_new_projects() {
    local known_projects_file="$DIR/.known_projects"
    
    # Scan for new directories with .gitignore files
    # Distinguish projects from library dependencies
    # Automatically categorize new projects
    # Integrate into unified system with user confirmation
}
# }}}
```

### 4. Health Monitoring and Reporting
```bash
# -- {{{ monitor_gitignore_health
function monitor_gitignore_health() {
    # Check for pattern conflicts in unified file
    # Verify patterns are still relevant
    # Detect obsolete or unused patterns
    # Generate health report with recommendations
}
# }}}
```

### 5. Automated Maintenance Scheduling
```bash
# -- {{{ schedule_maintenance
function schedule_maintenance() {
    # Daily change detection
    # Weekly health monitoring
    # Monthly full regeneration option
    # Integration with git hooks for automatic triggers
}
# }}}
```

### 6. Interactive Maintenance Tools
```bash
# -- {{{ interactive_maintenance_mode
function interactive_maintenance_mode() {
    echo "=== Gitignore Maintenance Tools ==="
    echo "1. Check for changes in project .gitignore files"
    echo "2. Scan for new projects"
    echo "3. Run health check on unified .gitignore"
    echo "4. Update unified .gitignore incrementally"
    echo "5. Full regeneration"
    echo "6. View maintenance history"
    
    # Handle user selection with appropriate actions
}
# }}}
```

## Implementation Details

### Change Detection Database
```bash
# .gitignore_checksums format:
# filepath:checksum:timestamp:size
/home/ritz/programming/ai-stuff/adroit/.gitignore:a1b2c3d4:1640995200:156
/home/ritz/programming/ai-stuff/progress-ii/.gitignore:e5f6g7h8:1640995300:203
```

### Incremental Update Strategy
```bash
# -- {{{ apply_incremental_update
function apply_incremental_update() {
    local project="$1"
    local updated_patterns="$2"
    
    # Locate project section in unified file
    # Update only that section while preserving structure
    # Recalculate any cross-project conflicts
    # Validate updated file integrity
}
# }}}
```

### Maintenance Configuration
```ini
# maintenance.conf
[detection]
scan_interval=daily
include_libraries=false
auto_integrate_new=ask

[updates]  
backup_before_update=true
preserve_manual_edits=true
validation_required=true

[monitoring]
health_check_interval=weekly
obsolete_pattern_detection=true
performance_monitoring=true
```

### Git Integration Hooks
```bash
# .git/hooks/post-merge
#!/bin/bash
# Auto-trigger maintenance after git operations
$DIR/scripts/generate-unified-gitignore.sh --check-changes --auto-update
```

### Maintenance History Tracking
```bash
# .gitignore_maintenance_log
2023-12-01 10:30 - Change detected in adroit/.gitignore
2023-12-01 10:31 - Incremental update applied successfully  
2023-12-01 10:32 - Validation passed
2023-12-07 09:00 - Weekly health check: no issues found
2023-12-15 14:20 - New project detected: handheld-office-v2
```

### Maintenance Report Generation
```bash
# -- {{{ generate_maintenance_report
function generate_maintenance_report() {
    cat > maintenance_report.md <<EOF
# Gitignore Maintenance Report
Generated: $(date)

## Recent Changes
- Last scan: $last_scan_date
- Changes detected: $changes_count
- Projects updated: $updated_projects

## Health Status
- Total patterns: $total_patterns
- Conflicts resolved: $resolved_conflicts
- Obsolete patterns: $obsolete_count
- Performance: $performance_status

## Recommendations
$maintenance_recommendations
EOF
}
# }}}
```

### Emergency Maintenance Procedures
```bash
# -- {{{ emergency_restore
function emergency_restore() {
    # Restore from backup if unified .gitignore causes issues
    # Rollback to previous working version
    # Generate emergency report
    # Notify about restoration
}
# }}}
```

## Related Documents
- `013-implement-validation-and-testing.md` - Uses validation for maintenance
- `015-integration-and-workflow-setup.md` - Integrates maintenance into workflows
- `002-gitignore-unification-script.md` - Parent ticket

## Tools Required
- File monitoring and checksum utilities
- Configuration file management
- Git hook integration
- Automated scheduling (cron or systemd timers)
- Report generation and logging

## Metadata
- **Priority**: Medium
- **Complexity**: Medium-High
- **Estimated Time**: 2-2.5 hours
- **Dependencies**: Issues 012, 013 (generation and validation)
- **Impact**: Long-term maintainability and automation
- **Status**: Completed 2025-12-18

## Success Criteria
- [x] Change detection system identifies modifications automatically
- [x] Incremental updates work correctly for minor changes
- [x] New projects can be integrated with minimal manual intervention
- [x] Health monitoring provides actionable insights
- [x] Maintenance history is tracked and accessible
- [x] Interactive tools support manual maintenance tasks
- [x] Emergency restoration procedures work reliably
- [x] Integration ready for automated scheduling and git workflows

## Completion Notes

**Implemented**: `delta-version/scripts/maintain-gitignore.sh`

**Features**:
- Change detection via MD5 checksums (--check)
- Health monitoring with duplicate/size checks (--health)
- New project detection (--new-projects)
- Status dashboard (--status)
- Backup management with emergency restore (--restore)
- Maintenance logging with timestamps
- Interactive mode (-I)

**State Files** (in `delta-version/assets/gitignore-state/`):
- checksums.txt - MD5 checksums of all tracked .gitignore files
- known-projects.txt - List of known projects
- maintenance.log - Activity log
- backups/ - Backup directory