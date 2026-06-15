# UT2K4 Symbeline Rumble - Documentation

## Table of Contents

### Project Overview
- [Architecture Overview](001-architecture-overview.md) - Core system components and platform targets
- [Roadmap](005-roadmap.md) - Development phases and milestones

### Technical Systems
- [Rendering System Overview](002-rendering-system.md) - Dynamic occlusion overview
- [Rendering System Technical](006-rendering-system-technical.md) - Deep dive: BSP, actors, performance
- [Game Mechanics](003-game-mechanics.md) - Resources, spawning, and player systems
- [AI Behavior](004-ai-behavior.md) - Bot behaviors and pathfinding

### Development Resources
- [OldUnreal Installation Guide](007-oldunreal-installation-guide.md) - Setting up UT2004 with native Linux compiler
- [Package Structure](008-package-structure.md) - Mod package organization and conventions
- Vision Document: `../notes/vision`
- Issue Files: `../issues/`
- Source Code: `../src/`

---

## Quick Start

1. Read the [Architecture Overview](001-architecture-overview.md) to understand the system
2. Review the [Roadmap](005-roadmap.md) to see development phases
3. Check `../issues/` for current work items
4. Refer to specific system docs as needed during development

---

## Project Structure

```
ut2k4-symbeline-rumble/
├── docs/           # Technical documentation
├── notes/          # Design notes and vision
├── src/            # Source code
├── libs/           # External libraries
├── assets/         # Game assets
├── issues/         # Issue tracking
│   └── completed/  # Completed issues
└── tmp/            # Temporary build files
```

---

## Related Resources

- Mono-repo utilities: See delta-guide.md (symlink in docs/ if available)
- Unreal Tournament 2004 Documentation: [UnrealWiki](https://unrealadmin.org/forums/)
- UnrealScript Reference: [UDN](https://docs.unrealengine.com/udk/Two/)
