# Adroit - Advanced RPG Character System

A comprehensive C-based RPG character generation and management library with modular integration capabilities.

## Features

- **Complete Character Generation**: 5 different stat generation methods with professional Raylib GUI
- **Equipment System**: Probability-based equipment generation with quality tiers
- **Modular Architecture**: Cross-language integration framework (C ↔ Bash ↔ Lua/LuaJIT)
- **Integration Ready**: Designed for seamless incorporation into other RPG projects

## Project Status

**Phase 1**: ✅ Complete Character Generation System (6/6 issues)
**Phase 2**: ✅ Modular Integration Architecture (3/3 issues)  
**Phase 3**: 🚧 Advanced Systems Implementation (8 issues planned)

## Library Usage

Adroit is designed as a dependency library for RPG projects. To include in your project:

```bash
# Dependency sync (automated in consuming projects)
git clone https://github.com/gabrilend/adroit.git libs/adroit
cd libs/adroit
make
```

### C Integration
```c
#include "libs/adroit/src/unit.h"
#include "libs/adroit/libs/common/logging.h"

Unit* character = init_unit();
// Character is ready with stats, equipment, etc.
```

### Cross-Language Integration
- **Bash Bridge**: Execute bash commands from C, designed for progress-ii integration
- **Lua Bridge**: High-performance scripting with LuaJIT support
- **Module System**: Template-driven integration for new projects

## Build Requirements

- GCC with C99 support
- Raylib (for GUI - auto-detected)
- Lua/LuaJIT (optional - for scripting features)
- POSIX-compliant system (Linux/macOS)

## Demo System

Run the demo selector to see all capabilities:
```bash
./demo_selector.sh
```

## Integration Examples

- **progress-ii**: AI-generated bash adventure game (primary integration target)
- **Future Projects**: Template system supports unlimited project integration

## Documentation

- [Technical Architecture](docs/technical-architecture.md)
- [Integration Guide](docs/integration-template.md)
- [Complete Issue History](docs/table-of-contents.md)

## Development

This project follows strict development methodology:
- All changes require issue tickets
- Issues are immutable and moved to `issues/completed/` when done
- Phase-based development with comprehensive testing
- CLAUDE.md compliant structure and workflows

## License

[License TBD - specify your preferred license]

---

*Part of the ai-stuff ecosystem - autonomous RPG experiences through AI and integration*