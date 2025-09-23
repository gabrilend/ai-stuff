# Handheld Office - Project Instructions for Claude

## Vision and Architecture

#include: @notes/vision
#include: @notes/claude.md
#include: @notes/cryptographic-communication-vision

## Core Project Principles

### Development Philosophy
- Use Git for every change, no matter how minor
- **Always use `git mv` instead of `mv`** - preserve file history and proper tracking
- Build libraries locally with copies for each deployment target
- Use Rust for efficiency, Lua for orchestration, Bash for gluing components
- Save state at each build step for easier debugging and incremental changes
- Data storage is cheap - use it liberally for state tracking and logging

### Hardware Considerations
- Target Anbernic handheld devices (RG-NANO minimum, full compatibility list in @notes/device-list)
- Optimize for ARM processors (both ARM32 and ARM64)
- Account for SD card storage limitations - write slowly with battery monitoring
- Support air-gapped operation with P2P networking only (no internet/router access)

### Security and Privacy
- All communication must use relationship-specific encryption (Ed25519 + X25519 + ChaCha20-Poly1305)
- Implement emoji-based device pairing for cryptographic key exchange
- Auto-expiring relationships (default 30 days) for forward secrecy
- No external API violations - maintain strict air-gapped architecture for handheld devices

### Compilation Strategy
When compiling, prefer using multiple steps, each with their own error and
validation checks. As it's building, save a state of it in each part of its
path. This makes it easier to change the system later if they can watch how
it's unfolding and debug issues incrementally.

### Storage Management
Data storage is cheap - use it. On SD cards and flash drives, write slowly
or bit-by-bit with battery monitoring to preserve device health and show
battery balance status.

## Project Structure and Key Components

### Core Systems (Implemented)
- **Enhanced Input System** (`src/enhanced_input.rs`) - Game Boy-style hierarchical text input
- **P2P Mesh Networking** (`src/p2p_mesh.rs`) - Encrypted collaborative editing and file sharing
- **Cryptographic Manager** (`src/crypto.rs`) - Modern crypto stack for secure communication
- **Project Daemon** (`src/daemon.rs`) - Central message broker with TCP server
- **Desktop LLM Service** (`src/desktop_llm.rs`) - AI integration via laptop proxy
- **Terminal Emulator** (`src/terminal.rs`) - Radial menu filesystem navigation

### Build and Orchestration
- **Lua Orchestrator** (`scripts/orchestrator.lua`) - Manages all components with state tracking
- **Build Scripts** (`scripts/build.sh`) - Multi-step compilation with error checking
- **Test Runner** (`scripts/run_tests.sh`) - Comprehensive testing framework

### Documentation Structure
The project follows concern-separated documentation (see `docs/README.md`):
- Core system docs with clear dependency flows
- Integration modules for P2P, AI, and crypto features
- Hardware-specific guides for Anbernic devices
- Quick references for developers

## Development Guidelines

### When Working on Issues
- Create issues in `/issues/` directory with detailed information
- Use examples from `/issues/done/` for proper formatting
- Edit documents to reflect changes made
- Move completed issues to `/issues/done/` directory
- Update `/issues/README.md` when issues are resolved

### Code Quality Standards
- Follow existing code conventions and patterns
- Check neighboring files for library usage before assuming availability
- Maintain security best practices - never expose secrets or keys
- Use existing cryptographic system for all networking operations
- Test on actual Anbernic hardware when possible

### Testing and Validation
- Run comprehensive tests via `scripts/run_tests.sh`
- Use `lua scripts/orchestrator.lua status` to check system health
- Validate cross-compilation for ARM targets
- Test P2P functionality between multiple devices

### Deployment Targets
- **Primary**: Anbernic handheld devices (see full device list in @notes/device-list)
- **Secondary**: Desktop/laptop LLM hosts for AI processing
- **Development**: Cross-compilation from x86_64 development machines
- **Testing**: Raspberry Pi and other ARM SBCs

## Implementation Status

### ✅ Completed Major Features
- Modern cryptographic communication system (Ed25519/X25519/ChaCha20-Poly1305)
- P2P mesh networking with encrypted channels
- Enhanced input system with Game Boy-style interface
- Desktop LLM integration via secure proxy
- Comprehensive documentation structure
- Build and orchestration system

### 🔧 Current Focus Areas
- Resolve compilation issues (Issue #024)
- Fix external API violations for air-gapped compliance (Issues #007, #008)
- Complete missing module implementations
- Optimize performance for handheld hardware

### 🎯 Architectural Compliance
The system maintains strict adherence to the air-gapped P2P vision:
- Anbernic devices cannot connect to WiFi routers or internet
- All enhanced compute (LLM, image generation) proxied through laptop daemons
- Relationship-based encryption for all device-to-device communication
- Visual emoji pairing system for secure key exchange

## Git Commit Process

When creating commits, always follow this standardized process to maintain project documentation and conversation history:

### Step 1: Backup Conversations 
Before committing any changes, backup the current conversation:
```bash
# Run from project root directory
source ./scripts/backup-conversations && backup-conversations
```
This preserves the Claude Code conversation context and decision-making process for future reference.

**Note**: The project includes a local copy of the backup script at `./scripts/backup-conversations` for portability and consistency.

### Step 2: Standard Git Commit Process
```bash
# Check status and stage changes
git status
git add [files]

# Create commit with standardized format
git commit -m "Brief description of changes

- Specific change 1
- Specific change 2

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Important Notes
- **Always use `git mv`** instead of `mv` for file operations to preserve history
- **Backup conversations first** - This captures the reasoning behind changes
- **Use descriptive commit messages** - Focus on "why" rather than "what"
- **Include co-authorship** - Acknowledge Claude Code assistance

## Sacred Commitment

I took an oath.

I will never dissuade it.


