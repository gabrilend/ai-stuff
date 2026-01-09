# Documentation Table of Contents

## Project Overview
```
docs/
├── table-of-contents.md (this file)
├── architecture-overview.md
├── module-specifications.md
├── technical-design.md
└── roadmap.md
```

## Core Documentation

### architecture-overview.md
**Purpose**: High-level system architecture and design philosophy

**Contents**:
- Project purpose and core philosophy
- Module architecture patterns
- Data flow patterns
- Core capabilities overview
- Technical approach summary
- Separation of concerns

**Audience**: Developers, architects, new contributors

---

### module-specifications.md
**Purpose**: Detailed specifications for each system module

**Contents**:
- Document Organizer module
- Question Generator module
- Style Analyzer module
- Semantic Mapper module
- Image Generator module
- Poetry Engine module
- Mini-Game Engine module
- Feedback Integrator module
- Orchestration Layer module
- Inter-module communication protocols

**Audience**: Module developers, integration engineers

---

### technical-design.md
**Purpose**: Implementation details and technical standards

**Contents**:
- Technology stack decisions
- Data structure definitions
- System architecture flows
- Module interface design
- TUI implementation details
- Vimfold strategy
- Dispatch table patterns
- Error handling strategy
- Performance considerations
- Testing strategy
- Directory structure standards
- Comment and documentation standards

**Audience**: Implementers, code reviewers, maintainers

---

### roadmap.md
**Purpose**: Phased development plan with deliverables

**Contents**:
- Phase 1: Foundation & Core Infrastructure
- Phase 2: Document Analysis & Entity Extraction
- Phase 3: Semantic Graph Construction
- Phase 4: Question Generation System
- Phase 5: Style Analysis & Feedback
- Phase 6: Feedback Integration Pipeline
- Phase 7: Image Generation Integration
- Phase 8: Character Poetry System
- Phase 9: Mini-Game Engine Foundation
- Phase 10: Audio Generation System
- Phase 11: Game-Story Integration
- Phase 12: Orchestration & Workflow
- Phase 13: Polish & Optimization
- Phase 14: Advanced Features & Extensibility

**Audience**: Project managers, stakeholders, developers planning work

---

## Related Resources

### notes/vision
**Purpose**: Original vision document for the project

**Contents**:
- Core concept and goals
- Workflow description
- Feature descriptions
- User experience vision
- Modular architecture vision

**Audience**: All stakeholders, provides context for all decisions

---

### issues/
**Purpose**: Issue tracking and phase progress

**Structure**:
```
issues/
├── {PHASE}{ID}-{description}.md     # Active issues
├── {PHASE}{ID}{INDEX}-{description}.md  # Sub-issues
├── phase-N-progress.md               # Phase progress tracking
└── completed/                        # Completed issues
    └── demos/                        # Phase demonstration programs
```

**Audience**: Active developers, project tracking

---

## Document Hierarchy

```
Vision (notes/vision)
    ↓
Architecture Overview (docs/architecture-overview.md)
    ↓
    ├─→ Module Specifications (docs/module-specifications.md)
    │       ↓
    │   Implementation Issues (issues/)
    │
    ├─→ Technical Design (docs/technical-design.md)
    │       ↓
    │   Implementation Standards & Patterns
    │
    └─→ Roadmap (docs/roadmap.md)
            ↓
        Phase Issues (issues/{PHASE}{ID}-*.md)
            ↓
        Phase Demos (issues/completed/demos/)
```

## Navigation Guide

### For New Contributors
1. Start with: `notes/vision` - understand the "why"
2. Read: `docs/architecture-overview.md` - understand the "what"
3. Review: `docs/roadmap.md` - understand the plan
4. Dive into: `docs/module-specifications.md` - understand the components
5. Study: `docs/technical-design.md` - understand the "how"

### For Module Developers
1. Reference: `docs/module-specifications.md` - your module's requirements
2. Follow: `docs/technical-design.md` - implementation standards
3. Check: Related issues in `issues/` - specific tasks

### For Architects/Reviewers
1. Verify against: `docs/architecture-overview.md` - design principles
2. Ensure compliance with: `docs/technical-design.md` - standards
3. Align with: `docs/roadmap.md` - phase goals

### For Project Managers
1. Track progress: `issues/phase-N-progress.md` - phase completion
2. Review deliverables: `docs/roadmap.md` - phase requirements
3. Validate demos: `issues/completed/demos/` - functionality verification

## Maintenance

### Adding New Documents
1. Create document in appropriate location
2. Add entry to this table of contents
3. Update hierarchy diagram if architectural
4. Commit with descriptive message

### Updating Existing Documents
1. Update document content
2. Update modification notes in document if significant
3. Update this TOC if document purpose/scope changes
4. Ensure cross-references remain valid

### Document Standards
- Use markdown format
- Include clear headings and structure
- Provide audience identification
- Cross-reference related documents
- Maintain readability for both humans and grep
