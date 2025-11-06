# RISC-V University

A dual-approach educational project for learning RISC-V assembly programming through both personal exploration and structured platform development.

## Project Versions

This project supports two distinct but complementary approaches to RISC-V education:

### Personal Playground (PC) Version
**Focus:** Individual exploration and discovery-based learning

- **File suffix:** `-pc`
- **Philosophy:** Broken by design, exploration-oriented, pattern discovery
- **Approach:** Ticket-driven learning with intentional incompleteness
- **Target:** Self-directed learners, researchers, enthusiasts

**Example files:**
- `docs/project-overview-pc.md` - Personal playground documentation
- `src/simulator-pc.js` - Exploration-focused source code
- `libs/learning-utils-pc.js` - Personal learning libraries
- `assets/diagram-pc.svg` - Learning resources and diagrams
- `issues/phase-1/001-exploration-setup-pc` - Personal learning tickets

### Educational Platform (EC) Version
**Focus:** Structured, scalable educational platform

- **File suffix:** `-ec`
- **Philosophy:** Comprehensive, accessible, standards-compliant
- **Approach:** Progressive curriculum with assessment and analytics
- **Target:** Students, educators, institutions

**Example files:**
- `docs/project-overview-ec.md` - Educational platform documentation
- `src/platform-ec.js` - Production-ready platform code
- `libs/educational-framework-ec.js` - Educational platform libraries
- `assets/curriculum-content-ec.json` - Platform resources and content
- `issues/phase-1/001-platform-infrastructure-ec` - Platform development tickets

## Shared Resources

### Vision Documents
- `notes/vision-personal-playground` - PC version philosophy and approach
- `notes/vision-educational-platform` - EC version goals and specifications

### Original Documentation
- `docs/` - Initial documentation (legacy)
- `issues/phase-1/` - Original development tickets

### Conversation Transcripts
- `llm-transcripts/` - Development conversation history with verbosity analysis

## Tab-Completion Friendly Structure

The suffix naming convention (`-pc`, `-ec`) ensures that:
- Tab completion groups related files together by directory/category
- Categories remain easily discoverable (e.g., `docs/project-` + Tab shows both versions)
- Dual-version nature is immediately apparent in filenames
- Content remains readable and accessible
- Standard directory structure maintained (`docs/`, `src/`, `libs/`, `assets/`, `issues/`)

## Getting Started

### For Personal Learning (PC)
1. Review `docs-pc/project-overview-pc.md`
2. Follow the exploration roadmap in `docs-pc/roadmap-pc.md`
3. Create learning tickets in `issues-pc/`
4. Begin hands-on exploration

### For Platform Development (EC)
1. Review `docs-ec/project-overview-ec.md`
2. Check technical requirements in `docs-ec/technical-requirements-ec.md`
3. Follow development roadmap in `docs-ec/roadmap-ec.md`
4. Set up development environment

## Development Philosophy

Both versions follow core principles from the CLAUDE.md instructions:
- Ticket-driven development (no work without issues)
- Vimfold function organization
- Script portability with configurable paths
- Interactive mode support
- Error-first approach over fallbacks

## Contributing

Choose your contribution style:
- **PC version:** Focus on learning patterns, exploration techniques, discovery documentation
- **EC version:** Focus on educational effectiveness, platform scalability, standards compliance

Both approaches welcome and complement each other in advancing RISC-V education.