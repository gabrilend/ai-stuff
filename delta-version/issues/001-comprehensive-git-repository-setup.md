# Issue 001-MASTER: Comprehensive Git Repository Setup (BROKEN DOWN)

## Current Behavior

The `/home/ritz/programming/ai-stuff/` directory contains multiple independent software projects, each with their own git repositories and development history:

### Existing Git Repositories
- **Main Repository**: `/home/ritz/programming/ai-stuff/.git` - Exists but has no commits, contains all projects as untracked files
- **adroit/**: Character system project with 1 commit (d0a0ec8)
- **progress-ii/**: Terminal game with 2 commits (c121808, b5f489d)
- **progress-ii/game-state/**: Nested game state repository with 1 commit (bf1b4ea)
- **risc-v-university/**: Educational project with 5+ commits, active development
- **magic-rumble/**: Game project with 1 commit (89ee180)
- **handheld-office/**: Office application with 4+ commits, active development

### Library Dependencies (External Repos)
- Various external libraries embedded in `libs/` directory
- Game development dependencies in project subdirectories
- Third-party tools in `console-demakes/tools/`

### Project Structure
- 20+ project directories with varying completion levels
- Mixed development states: some functional, others in early vision stage
- Individual `.gitignore` files in various projects
- CLAUDE.md files providing project-specific instructions

## Intended Behavior

Create a unified git repository system where:

1. **Master Branch**: Contains all projects and serves as the complete collection
2. **Project Branches**: Each main project gets its own isolated branch containing only its files
3. **History Preservation**: All existing git commit history is maintained in respective project branches
4. **Branch Isolation**: Project branches only show their specific files when checked out
5. **Remote Integration**: Repository hosted on GitHub with proper remote configuration
6. **Unified Gitignore**: Master `.gitignore` aggregated from all individual project `.gitignore` files

## BREAKDOWN NOTICE

**This issue has been broken down into individual implementation issues:**

- **Issue 001**: Prepare Repository Structure
- **Issue 004**: Extract Project Histories  
- **Issue 005**: Configure Branch Isolation
- **Issue 006**: Initialize Master Branch
- **Issue 007**: Remote Repository Setup
- **Issue 008**: Validation and Documentation

**Dependencies:** Issue 002 (Gitignore Unification Script) should be completed before Issue 006.

**Recommended Implementation Order:**
1. Issue 001 (Prepare Repository Structure)
2. Issue 002 (Gitignore Unification Script)
3. Issue 004 (Extract Project Histories)
4. Issue 005 (Configure Branch Isolation)
5. Issue 006 (Initialize Master Branch)
6. Issue 007 (Remote Repository Setup)
7. Issue 008 (Validation and Documentation)

## Original Implementation Steps (Reference)

### 1. Prepare Repository Structure → Issue 001
### 2. Extract Project Histories → Issue 004
### 3. Configure Branch Isolation → Issue 005
### 4. Initialize Master Branch → Issue 006
### 5. Remote Repository Setup → Issue 007
### 6. Validation and Documentation → Issue 008

## Related Documents
- `/home/ritz/.claude/CLAUDE.md` - Global project instructions
- `/mnt/mtwo/.claude/CLAUDE.md` - Project-specific instructions  
- `/mnt/mtwo/programming/ai-stuff/.git/CLAUDE.md` - Git-specific instructions

## Tools Required
- git subtree/filter-branch for history extraction
- GitHub CLI for remote setup
- Custom scripts for gitignore aggregation
- Branch management utilities

## Metadata
- **Priority**: High
- **Complexity**: Advanced
- **Estimated Time**: 2-3 hours
- **Dependencies**: None
- **Impact**: Repository structure, development workflow