# Delta-Version Project Structure

## Overview
Delta-Version is organized as the meta-project for git repository management within the AI project collection.

## Directory Structure

```
delta-version/
├── docs/                    # Project documentation
│   ├── project-structure.md # This file
│   └── api-reference.md     # Script and utility documentation
├── notes/                   # Design documents and vision
│   └── vision.md           # Project vision and scope
├── src/                     # Source implementations
├── scripts/                 # Repository management utilities
│   ├── list-projects.sh               # Project discovery utility
│   ├── analyze-gitignore.sh           # Gitignore file discovery and analysis
│   ├── design-unification-strategy.sh # Conflict resolution strategy design
│   └── process-gitignore-patterns.sh  # Pattern processing and categorization
├── libs/                    # Shared libraries and modules
├── assets/                  # Templates and configuration files
└── issues/                  # Issue tracking for this project
    ├── progress.md         # Progress tracking
    ├── 001-*.md           # Git repository setup issues
    ├── 009-015-*.md       # Gitignore unification issues
    └── 016-022-*.md       # Ticket distribution issues
```

## Project Scope

Delta-Version encompasses all repository-level functionality:

- **Git Repository Management**: Branch isolation, history preservation, remote setup
- **Unified Tooling**: Cross-project utilities and automation
- **Issue Coordination**: Meta-project issue tracking and progress management
- **Documentation**: Repository structure and workflow documentation

## Integration Points

Delta-Version provides services to all other projects in the repository:

- Project discovery and listing
- Cross-project ticket distribution
- Repository maintenance and validation
- Git workflow automation

## Development Guidelines

- Follow CLAUDE.md conventions for all implementations
- Maintain project-agnostic approach (no hardcoded project names)
- Ensure all scripts work from any directory via `DIR` variable
- Use vimfolds for function organization
- Include interactive and headless modes for all utilities