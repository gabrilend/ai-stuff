# ao3-source-code-import Roadmap

## Phase 1: Research & Specification

Understand AO3's requirements, limitations, and interface mechanisms.

- Research AO3 HTML sanitization rules
- Document allowed tags and formatting
- Investigate authentication methods (session cookies, CSRF tokens)
- Identify rate limits and ToS considerations
- Document the work creation/update API or form structure

## Phase 2: Source Code Reader

Build the component that reads and parses a git repository.

- Read directory structure from target repo
- Parse file contents with metadata (path, size, type)
- Extract git log and commit history
- Read project documentation (README, vision, issues)
- Build internal representation of "the work"

## Phase 3: HTML Formatter

Transform parsed source into AO3-compatible HTML.

- Design chapter organization strategy
- Build code-to-HTML converter with syntax preservation
- Format metadata as readable prose
- Generate work summary from project docs
- Create tag suggestions based on project content

## Phase 4: AO3 Interface

Build the upload mechanism.

- Implement session authentication
- Build work creation form submission
- Implement chapter upload/update
- Handle CSRF token extraction
- Implement error handling and retry logic

## Phase 5: Version Management

Handle the deprecation/replacement cycle.

- Track uploaded work IDs locally
- Implement "delete previous version" workflow
- Build differential update detection
- Create upload history log
- Implement dry-run mode for testing

## Phase 6: Integration & CLI

Tie it all together into a usable tool.

- Create main CLI interface
- Build configuration file support
- Implement full pipeline: read -> format -> upload
- Create phase demo showing complete workflow
- Document usage and examples
