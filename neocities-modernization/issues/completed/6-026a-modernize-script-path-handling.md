# Issue 026a: Modernize Script Path Handling

## Current Behavior
- Legacy scripts in `/scripts/` directory use hard-coded absolute paths
- `run-fediverse` uses `/home/ritz/backups/fediverse` 
- `update` uses `/home/ritz/backups/words`, `/home/ritz/words`
- `compile` uses hard-coded paths to various directories
- Scripts cannot be run from different directories or by different users
- No integration with project's `${DIR}` variable system

## Intended Behavior
- All scripts use project `${DIR}` variable for path resolution
- Scripts work when run from any directory
- Paths are relative to project root where possible
- Maintain backward compatibility through configuration
- Follow project conventions established in `run.sh` and other scripts
- Scripts can be easily relocated or used by different users

## Suggested Implementation Steps

1. **Audit Current Path Usage**: Document all hard-coded paths in legacy scripts
2. **Implement DIR Variable**: Add DIR variable setup to each script
3. **Convert Path References**: Replace absolute paths with DIR-relative paths
4. **Add Configuration Layer**: Create config file for any necessary absolute paths
5. **Test Integration**: Verify scripts work with project directory structure
6. **Update Documentation**: Document new path conventions

## Technical Requirements

### **Script Path Standardization**
All scripts should follow this pattern:
```bash
#!/bin/bash
# Script description and general functionality overview

# {{{ setup_dir_path
setup_dir_path() {
    if [ -n "$1" ]; then
        echo "$1"
    else
        echo "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
    fi
}
# }}}

# Parse command line arguments
DIR=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            DIR="$1"
            shift
            ;;
    esac
done

# Set up directory
DIR=$(setup_dir_path "$DIR")
```

### **Path Conversion Strategy**

#### **Legacy Paths → Project Paths**
- `/home/ritz/backups/fediverse` → `${DIR}/input/fediverse-backup`
- `/home/ritz/backups/messages-to-myself` → `${DIR}/input/messages-backup`
- `/home/ritz/words` → `${DIR}/input/words`
- `/home/ritz/notes` → `${DIR}/input/notes`

#### **Configuration File Structure**
```json
{
  "input_sources": {
    "fediverse_backup_path": "/home/ritz/backups/fediverse",
    "messages_backup_path": "/home/ritz/backups/messages-to-myself", 
    "words_source_path": "/home/ritz/words",
    "notes_source_path": "/home/ritz/notes"
  },
  "project_structure": {
    "input_dir": "input",
    "scripts_dir": "scripts",
    "output_dir": "output"
  }
}
```

### **Priority Script Updates**

#### **1. update script** - High Priority
Current hard-coded paths:
- `TARGET_DIR="/home/ritz/words"`
- `NOTES_DIR="/home/ritz/notes"`
- `FEDI_DIR="/home/ritz/backups/fediverse"`
- `MSG_DIR="/home/ritz/backups/messages-to-myself"`

Updated approach:
```bash
# Load configuration
CONFIG_FILE="${DIR}/config/input-sources.json"
TARGET_DIR="${DIR}/input/words"
# Source paths from config or environment variables
```

#### **2. extract-fediverse.lua** - High Priority  
Current hard-coded paths:
- `local file = "/home/ritz/backups/fediverse/extract/outbox.json"`
- `local save_location = "/home/ritz/backups/fediverse/files"`

Updated approach:
```lua
-- {{{ setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

local DIR = setup_dir_path(arg and arg[1])
local file = DIR .. "/input/fediverse-backup/extract/outbox.json"
local save_location = DIR .. "/input/fediverse-backup/files"
```

#### **3. run-fediverse and run-messages** - Medium Priority
Convert to use project directory structure and config-based source paths.

## Quality Assurance Criteria

- **Path Portability**: All scripts work when project is moved to different directory
- **User Independence**: Scripts work for different users without modification
- **Configuration Driven**: External paths configurable without script modification
- **Backward Compatible**: Existing functionality preserved during transition
- **Error Handling**: Clear error messages when paths don't exist
- **Documentation**: Updated path conventions documented

## Success Metrics

- **100% Hard-coded Path Removal**: No absolute paths remain in script files
- **Cross-User Compatibility**: Scripts work for any user with project access
- **Directory Independence**: Scripts work when run from any directory
- **Configuration Integration**: External paths managed through config files
- **Preservation of Functionality**: All existing script capabilities maintained

## Dependencies

- **Project Configuration System**: May require extending config/input-sources.json
- **Directory Structure**: May need to create input/ subdirectories
- **Testing Framework**: Need way to test scripts in different environments

## Related Issues

- **Parent**: Issue 6-026 (Scripts Directory Integration)
- **Blocks**: Issues 6-017 (Image Integration), 6-025 (Chronological Sorting)
- **Follows**: Project path standardization conventions from run.sh

## Testing Strategy

1. **Path Verification**: Test scripts with different DIR values
2. **Cross-User Testing**: Test scripts as different users
3. **Missing Path Handling**: Verify error handling when paths don't exist
4. **Functionality Preservation**: Ensure all existing capabilities work
5. **Integration Testing**: Verify scripts work within main project workflow

**ISSUE STATUS: COMPLETED** ✅🔧

**Completed**: December 13, 2025 - Path modernization successfully implemented

---

## 🎉 **IMPLEMENTATION RESULTS**

### **All Requirements Successfully Implemented**:

1. ✅ **Project DIR Variable**: All scripts now use `${DIR}` variable with `setup_dir_path()` function
2. ✅ **Configuration System**: Created `/config/input-sources.json` with project-relative paths  
3. ✅ **Script Modernization**: All bash and Lua scripts accept project directory parameter
4. ✅ **Library Consolidation**: Moved `dkjson.lua` to `/libs/` for shared project use
5. ✅ **Path Conversion**: Converted all hard-coded paths to project-relative structure

#### **✅ Scripts Updated**:
- **Bash scripts**: `update`, `run-fediverse`, `run-messages` - all use project DIR
- **Lua scripts**: `extract-fediverse.lua`, `extract-messages.lua` - project directory aware
- **Configuration**: JSON-based path mapping with fallback defaults

#### **✅ Path Mapping**:
- `/home/ritz/backups/fediverse` → `${DIR}/input/fediverse`
- `/home/ritz/backups/messages-to-myself` → `${DIR}/input/messages`
- All paths now relative to project root with configuration override capability

**Foundation Complete**: Ready for Issues 6-026b, 6-026c, and 6-026d. All scripts are portable and project-directory independent.