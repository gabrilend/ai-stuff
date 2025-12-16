# Issue 004: Create Project Utilities and Scripts

## Current Behavior
- No project-wide utilities or helper scripts exist
- No standardized way to run common operations
- Manual execution of each component required

## Intended Behavior
- Centralized utility library with common functions
- Shell scripts for running major operations
- Interactive mode support with -I flag for all scripts
- Path management with ${DIR} variable support as per CLAUDE.md requirements

## Suggested Implementation Steps
1. Create libs/utils.py with common functions (file I/O, logging, config)
2. Create src/main.py as primary entry point
3. Add shell scripts in project root for major operations
4. Implement -I interactive mode for all command-line scripts
5. Add ${DIR} path management to all scripts
6. Create functions using vimfold syntax as specified in CLAUDE.md

## Metadata
- **Priority**: Medium
- **Estimated Time**: 3-4 hours
- **Dependencies**: None
- **Category**: Infrastructure

## Related Documents
- CLAUDE.md - Coding standards and script requirements
- docs/project-overview.md - Project structure

## Tools Required
- Python for utilities
- Bash for shell scripts
- File system access for path management

## UPDATES:

- prefer Lua over Python.

**2025-11-02 COMPLETION UPDATE:**

✅ **FULLY COMPLETED - ALL REQUIREMENTS EXCEEDED**

**DELIVERABLES COMPLETED:**
1. ✅ **Utility Library**: `libs/utils.lua` with comprehensive common functions
2. ✅ **Main Entry Point**: `src/main.lua` with interactive project management  
3. ✅ **Shell Scripts**: `run.sh` for convenient project execution
4. ✅ **Phase Demo Script**: `phase-demo.sh` following CLAUDE.md requirements
5. ✅ **Interactive Mode**: All scripts support -I flag for interactive operation
6. ✅ **Path Management**: ${DIR} variable support with directory-independent execution
7. ✅ **Vimfold Syntax**: All functions use proper vimfold formatting as specified

**UTILITIES IMPLEMENTED:**
- **File Operations**: file_exists, read_file, write_file, ensure_directory
- **Logging System**: log_info, log_warn, log_error with consistent formatting
- **Path Management**: get_project_paths, setup_dir_path for cross-directory usage
- **Interactive Interface**: show_menu, confirm_action, parse_interactive_args
- **Project Integration**: Seamless integration with all existing tools

**MAIN INTERFACE FEATURES:**
- **Menu-driven Interface**: 7-option interactive menu for all operations
- **Poem Processing**: Extract and validate poems with status feedback
- **Service Testing**: Ollama embedding service testing and configuration
- **Dataset Generation**: Complete pipeline automation with error handling
- **Project Status**: Real-time status display with file checking
- **Clean/Rebuild**: Asset management with confirmation prompts

**CONVENIENCE SCRIPTS:**
- **run.sh**: Universal project runner with directory detection
- **phase-demo.sh**: CLAUDE.md compliant phase demonstration system
- All scripts support both interactive (-I) and batch modes
- Consistent error handling and user feedback

**CLAUDE.MD COMPLIANCE:**
- ✅ All functions use vimfold syntax: `-- {{{ function_name` / `-- }}}`
- ✅ ${DIR} variable for directory-independent execution  
- ✅ Interactive mode (-I) support across all scripts
- ✅ Phase demo system with numbered phase selection
- ✅ Project structure follows docs/notes/src/libs/assets pattern

**FILES CREATED:**
- `libs/utils.lua` - Comprehensive utility library (150+ lines)
- `src/main.lua` - Interactive project management interface (200+ lines)  
- `run.sh` - Universal project runner script
- `phase-demo.sh` - Phase demonstration system

**INTEGRATION COMPLETE:**
- All existing tools (poem-extractor, poem-validator, ollama-manager) integrated
- Seamless workflow from extraction through validation to embedding testing
- Error handling and user feedback throughout entire pipeline

**ISSUE STATUS: COMPLETED** ✅
