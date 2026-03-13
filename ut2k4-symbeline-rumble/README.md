# UT2K4 Symbeline Rumble

A total conversion mod for Unreal Tournament 2004 that brings Warcraft Rumble-style gameplay mechanics to the classic arena shooter.

## Project Vision

Symbeline Rumble transforms UT2004 into a tactical unit-spawning game where players control the battlefield from a top-down perspective, spawning AI-controlled units with unique weapon-based behaviors.

See `notes/vision` for the complete project vision.

## Current Status

**Phase 1**: Foundation and Basic Infrastructure (In Progress)

The project is currently in the initial setup phase. See `issues/phase-1-progress.md` for detailed progress tracking.

## Documentation

All project documentation is in the `docs/` directory:

- [Table of Contents](docs/000-table-of-contents.md) - Documentation index
- [Architecture Overview](docs/001-architecture-overview.md) - System design
- [Roadmap](docs/005-roadmap.md) - 12-phase development plan

## Development

### Prerequisites
- Unreal Tournament 2004 (Linux version)
- Bash shell
- Text editor

### Quick Start

1. Complete setup (see `issues/101-setup-dev-environment.md`)
2. Build the mod: `./scripts/compile.sh`
3. Test in-game: `./scripts/test.sh`

### Scripts

Build and development scripts are in `scripts/`:
- `compile.sh` - Compile the mod
- `test.sh` - Launch UT2004 with mod for testing
- `clean.sh` - Clean build artifacts
- `watch-log.sh` - Monitor UT2004 log in real-time

## Project Structure

```
ut2k4-symbeline-rumble/
├── docs/           # Technical documentation
├── notes/          # Design notes and vision
├── src/            # UnrealScript source code
├── issues/         # Issue tracking and progress
├── scripts/        # Build and development automation
├── assets/         # Game assets
├── libs/           # External libraries
├── input/          # Input files for processing
├── output/         # Generated output files
└── tmp/            # Temporary build files
```

## Contributing

This project follows a strict issue-driven development process:

1. All work must have an associated issue file
2. Issues follow naming convention: `{PHASE}{ID}-{description}`
3. Issues are immutable - add notes, don't delete
4. Completed issues move to `issues/completed/`
5. Each phase ends with a demo in `issues/completed/demos/`

See `docs/000-table-of-contents.md` for full development guidelines.

## License

(To be determined)

## Platform

**Primary Target**: UT2004 Linux (base version)
**Secondary Target**: Latest UT2004 version (feature parity)

The Linux version is the canonical implementation. All development targets Linux first.

## Contact

GitHub: @gabrilend
