# Delta-Version Documentation Table of Contents

## Project Documentation

### Core Documentation
- [README](../README.md) - Project overview and quick reference 📝
- [Delta Guide](delta-guide.md) - Comprehensive maintainer guide (symlinked to all projects)
- [Quick Start](QUICK-START.md) - Get up and running in 5 minutes 📝
- [Project Structure](project-structure.md) - Delta-Version directory organization and scope
- [Development Roadmap](roadmap.md) - Sequential development phases and feature planning
- [Project Status](PROJECT-STATUS.md) - Current state and completion overview 📝
- [API Reference](api-reference.md) - Script and utility documentation
- [Development Guide](development-guide.md) - Conventions, patterns, and best practices
- [Issue Template](issue-template.md) - Standard template for creating issues
- [Troubleshooting](TROUBLESHOOTING.md) - Solutions for common issues and edge cases 📝
- [Performance Testing](performance-testing.md) - Benchmarking and optimization guide 📝

### Tool Guides
- [History Tools Guide](history-tools-guide.md) - reconstruct-history.sh and generate-history.sh 📝
- [External Projects Guide](external-projects-guide.md) - Configure external project directories 📝
- [Git Worktree Guide](worktree-guide.md) - Multi-agent parallel development with git worktrees 📝
- [Project Metadata Schema](project-metadata-schema.md) - project.meta.json format and manage-metadata.sh
- [Storyline Library Builder](../scripts/build-storyline-library.info.md) - Chronological transcript shelf: usage, pieces, and deliberate behaviors
- [The Library](../library/README.md) - Generated read-only views over the collection's history
- [HISTORY.txt](HISTORY.txt) - Generated commit history narrative

### Design Documents
- [Vision](../notes/vision.md) - Project vision and scope definition
- [Keyword Markup Language Spec](keyword-markup-language-spec.md) - KML syntax for dynamic ticket templates 📝
- [Per-Issue Transcript Generation](per-issue-transcript-generation-design.md) - Multi-level transcript caching per completed issue 📝

## Issue Tracking

### Phase 1: Foundation Infrastructure
- [Phase 1 Progress](../issues/phase-1/progress.md) - Foundation infrastructure development status
- [Issue 001: Prepare Repository Structure](../issues/phase-1/001-prepare-repository-structure.md) ✅
- [Issue 023: Create Project Listing Utility](../issues/phase-1/023-create-project-listing-utility.md) ✅
- [Issue 025: Repository Structure Validation](../issues/phase-1/025-repository-structure-validation.md) 🔄
- [Issue 026: Project Metadata System](../issues/phase-1/026-project-metadata-system.md) 🔄
- [Issue 027: Basic Reporting Framework](../issues/phase-1/027-basic-reporting-framework.md) 📋
- [Issue 028: Foundation Demo Script](../issues/completed/028-foundation-demo-script.md) ✅

### Foundation Issues (Tier 1)

### Phase 2: Gitignore Unification System
- [Phase 2 Progress](../issues/phase-2/progress.md) - Gitignore unification development status
- [Issue 010: Design Unification Strategy](../issues/phase-2/010-design-unification-strategy.md) ✅
- [Issue 011: Implement Pattern Processing](../issues/phase-2/011-implement-pattern-processing.md) ✅
- [Issue 012: Generate Unified Gitignore](../issues/phase-2/012-generate-unified-gitignore.md) 📋
- [Issue 013: Implement Validation and Testing](../issues/phase-2/013-implement-validation-and-testing.md) 📋
- [Issue 014: Create Maintenance Utilities](../issues/phase-2/014-create-maintenance-utilities.md) 📋

### Infrastructure Issues (Tier 2)
- [Issue 009: Discover and Analyze Gitignore Files](../issues/009-discover-and-analyze-gitignore-files.md) ✅

### Git Repository Management Issues
- [Issue 004: Extract Project Histories](../issues/004-extract-project-histories.md)
- [Issue 005: Configure Branch Isolation](../issues/005-configure-branch-isolation.md)
- [Issue 006: Initialize Master Branch](../issues/006-initialize-master-branch.md)
- [Issue 007: Remote Repository Setup](../issues/007-remote-repository-setup.md)
- [Issue 008: Validation and Documentation](../issues/completed/008-validation-and-documentation.md) ✅

### Gitignore System Issues
- [Issue 013: Implement Validation and Testing](../issues/013-implement-validation-and-testing.md)
- [Issue 014: Create Maintenance Utilities](../issues/014-create-maintenance-utilities.md)
- [Issue 015: Integration and Workflow Setup](../issues/015-integration-and-workflow-setup.md)

### Ticket Distribution System Issues
- [Issue 016: Design Keyword Markup Language](../issues/016-design-keyword-markup-language.md)
- [Issue 017: Implement Keyword Processing Engine](../issues/017-implement-keyword-processing-engine.md)
- [Issue 018: Create Project Discovery System](../issues/018-create-project-discovery-system.md)
- [Issue 019: Implement Ticket Distribution Engine](../issues/019-implement-ticket-distribution-engine.md)
- [Issue 020: Create Interactive Interface](../issues/020-create-interactive-interface.md)
- [Issue 021: Implement Validation and Testing System](../issues/021-implement-validation-and-testing-system.md)
- [Issue 022: Create Integration and Workflow System](../issues/022-create-integration-and-workflow-system.md)

### History Reconstruction Issues
- [Issue 035: Project History Reconstruction](../issues/completed/035-project-history-reconstruction.md) ✅
  - [Issue 035a: Project Detection and Import](../issues/completed/035a-project-detection-and-import.md) ✅
  - [Issue 035b: Dependency Graph and Topological Sort](../issues/completed/035b-dependency-graph-topological-sort.md) ✅
  - [Issue 035c: Date Estimation and Interpolation](../issues/completed/035c-date-estimation-interpolation.md) ✅
  - [Issue 035d: File-to-Issue Association](../issues/completed/035d-file-to-issue-association.md) ✅
  - [Issue 035e: History Rewriting on Orphan Branch](../issues/completed/035e-history-rewriting-rebase.md) ✅
  - [Issue 035f: Local LLM Integration](../issues/completed/035f-local-llm-integration.md) ✅
  - [Issue 035g: Transcript-to-Commit Provenance](../issues/completed/035g-transcript-to-commit-provenance.md) ✅
- [Issue 036: Commit History Viewer](../issues/036-commit-history-viewer.md) 📋
- [Issue 037: Project History Narrative Generator](../issues/completed/037-project-history-narrative-generator.md) ✅

### Utility Issues
- [Issue 028: Foundation Demo Script](../issues/completed/028-foundation-demo-script.md) ✅
- [Issue 029: Demo Runner Script](../issues/completed/029-demo-runner-script.md) ✅
- [Issue 030: Issue Management Utility](../issues/completed/030-issue-management-utility.md) ✅
- [Issue 031: Import Project Histories](../issues/completed/031-import-project-histories.md) ✅
- [Issue 042: Utility Health Checker](../issues/042-utility-health-checker.md) 📝

### Enhancement Issues
- [Issue 024: External Project Directory Configuration](../issues/024-external-project-directory-configuration.md) 📝
- [Issue 032: Project Donation/Support Links](../issues/032-project-donation-support-links.md) 📝

### Multi-Agent Infrastructure Issues
- [Issue 041: Git Worktree Multi-Agent Architecture](../issues/completed/041-git-worktree-multi-agent-architecture.md) ✅

### Dynamic CLAUDE.md System Issues
- [Issue 040: Dynamic CLAUDE.md Revision System](../issues/040-dynamic-claudemd-revision-system.md) 📝
  - [Issue 040a: Design Event Taxonomy](../issues/040a-design-event-taxonomy.md) 📝
  - [Issue 040b: Build API Layer](../issues/040b-build-api-layer.md) 📝
  - [Issue 040c: Implement Revision Engine](../issues/040c-implement-revision-engine.md) 📝
  - [Issue 040d: Create History Audit System](../issues/040d-create-history-audit-system.md) 📝
  - [Issue 040e: Build Validation System](../issues/040e-build-validation-system.md) 📝
  - [Issue 040f: Create Interactive Interface](../issues/040f-create-interactive-interface.md) 📝
  - [Issue 040g: Transcript Analysis Memory](../issues/040g-transcript-analysis-memory.md) 📝
  - [Issue 040h: Worldbuilding Design Oracle](../issues/040h-worldbuilding-design-oracle.md) 📝
  - [Issue 040i: Continual Co-operation Bridge](../issues/040i-continual-cooperation-bridge.md) 📝

### Master Reference Issues
- [Issue 001: Comprehensive Git Repository Setup](../issues/001-comprehensive-git-repository-setup.md) - Master reference
- [Issue 002: Gitignore Unification Script](../issues/002-gitignore-unification-script.md) - Master reference
- [Issue 003: Dynamic Ticket Distribution System](../issues/003-dynamic-ticket-distribution-system.md) - Master reference

## Progress Tracking
- [Project Progress](../issues/progress.md) - Overall progress and implementation status

## Configuration Files
- [External Projects Configuration](../config/external-projects.conf) - External directory setup
- [Ticket Keywords Configuration](../config/ticket-keywords.conf) - KML keyword definitions 📝

## Templates
- [Project CLAUDE.md Template](../assets/project-claude-md-template.md) - Source control guidelines for project CLAUDE.md files

## Implementation Guidelines
- [CLAUDE.md](../issues/CLAUDE.md) - Project-specific implementation conventions

---
**Legend**: ✅ Completed | 📝 New | 🔄 In Progress