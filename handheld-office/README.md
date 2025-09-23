# Handheld Office 🎮

A Game Boy Advance SP-inspired text editor with hierarchical input and networked AI assistance. Perfect for Anbernic devices and other handheld systems!

## Vision

Imagine a text editor on a Game Boy Advance SP with:
- Hierarchical tree-based text input using D-pad navigation
- 8-way radial menu controlled with A/B/L/R buttons
- L-shaped text display (line across top and down right side)
- Network connectivity for real-time collaboration
- Local AI infrastructure for LLM assistance over LAN

## What's Built

**Project Daemon** (`src/daemon.rs`):
- Central message broker handling communication between devices
- State persistence with 30-second intervals to `files/build/`
- TCP server on port 8080 for LAN connectivity
- Message routing between handheld and desktop/cluster

**Enhanced Input System** (`src/enhanced_input.rs`, `src/input_config.rs`):
- Advanced multi-mode input system with Game Boy and SNES controller support
- Edit mode with SELECT button entry and cursor navigation
- One-time keyboard for character input with radial menus
- SNES-style 6-option radial character selection
- P2P-enabled collaborative document editing and real-time synchronization
- User-configurable layouts via JSON files
- See [Enhanced Input Documentation](docs/enhanced-input-system.md) for details

**P2P Mesh File Sharing System** (`src/p2p_mesh.rs`):
- Battery-efficient peer-to-peer networking optimized for handheld devices
- Real-time collaborative editing across multiple devices
- Automatic file sharing and discovery between handheld devices
- 32KB chunked transfers with SHA-256 verification
- Integrated across media player, paint program, and word processor
- See [P2P Mesh Documentation](docs/p2p-mesh-system.md) for complete guide

**Handheld Client** (`src/handheld.rs`):
- Game Boy-style hierarchical input system using A/B/L/R buttons
- L-shaped text display as described in your vision
- Network connectivity to daemon for real-time collaboration
- LLM request capability with `llm:prompt` commands

**Terminal Emulator** (`src/terminal.rs`):
- Radial menu filesystem navigation optimized for handheld devices
- Interactive bash command builder with Game Boy-style rendering
- File operations and command execution via radial interface
- Command history and execution with 80x24 character display

**Desktop LLM Service** (`src/desktop_llm.rs`):
- Automatic detection of local LLM backends (Ollama, LlamaCPP, KoboldCPP)
- Processes LLM requests from handheld devices
- Falls back gracefully between different AI systems

**Lua Orchestrator** (`scripts/orchestrator.lua`):
- Manages all components with state tracking
- Commands: `build`, `run`, `start-daemon`, `start-llm`, `stop`, `status`
- Saves build states incrementally as requested

## Quick Start

### Build Everything
```bash
./scripts/build.sh
```

### Set up AI Infrastructure (on desktop/cluster)
```bash
./scripts/setup_llm.sh
```

### Run Full System
```bash
lua scripts/orchestrator.lua run
```

### Manual Component Control
```bash
# Start daemon
lua scripts/orchestrator.lua start-daemon

# Start LLM service (on desktop/cluster)
lua scripts/orchestrator.lua start-llm

# Start handheld client
lua scripts/orchestrator.lua start-handheld
```

## Usage

### Enhanced Input System

The handheld devices support multiple input modes with P2P collaboration:

**Basic Mode (Game Boy style):**
- Navigate through character sectors with D-pad
- 4-character groups per sector (A-D, E-H, etc.)
- SELECT enters edit mode for cursor navigation
- A button opens one-time keyboard for character selection
- START opens P2P browser when P2P is enabled

**Advanced Mode (SNES style):**
- D-pad directions open 6-option radial menus
- UP: Uppercase letters, DOWN: Lowercase letters
- LEFT: Numbers, RIGHT: Special characters
- 6 face buttons (A/B/X/Y/L/R) select from radial menu
- Y button toggles P2P features on/off
- X button opens document saver for P2P sharing

**P2P Collaboration Features:**
- Real-time collaborative document editing between devices
- Automatic file sharing and discovery
- Battery-efficient networking with 32KB chunk transfers
- Document synchronization with conflict resolution
- Cross-device artwork and media sharing

**Common Features:**
- Text displays in L-shaped format
- Edit mode with cursor navigation using D-pad
- Configurable via JSON files
- Send LLM requests with `llm:your prompt here`

See [Enhanced Input Documentation](docs/enhanced-input-system.md) for complete usage guide.
See [P2P Mesh Documentation](docs/p2p-mesh-system.md) for collaboration features.

### LLM Integration

The system automatically tries these LLM backends in order:
1. Ollama (localhost)
2. LlamaCPP (localhost:8000)
3. KoboldCPP (localhost:5001)
4. Echo fallback

### Directory Structure

```
/
├── notes/           - Documentation and design notes
├── files/
│   ├── build/       - Build artifacts and state files
│   └── crash/       - Crash dumps and debug info
├── trash/           - Temporary files
├── HDMIS/          - Hardware interface modules
└── src/            - Source code
```

## Development Philosophy

- Use Git for every change, no matter how minor
- Build libraries locally with copies for each deployment
- Use Rust for efficiency, Lua for orchestration, Bash for gluing
- Save state at each build step for easier debugging
- Data storage is cheap - use it liberally
- Write slowly to SD cards/flash drives with battery monitoring

## Technical Details

### Networking
- TCP communication between components
- JSON message protocol
- Automatic device discovery on LAN
- State synchronization across devices

### Input Hierarchy
- Configurable key mappings
- Multi-layer navigation
- Visual feedback for current selection
- Efficient text entry for constrained input

### State Management
- Persistent state saves to `files/build/`
- Automatic recovery from crashes
- Build state tracking for incremental compilation
- Message history and replay capability

## Deployment Guide

### Anbernic Handhelds (RG35XX, RG351P, RG552, etc.)

**Prerequisites:**
- Custom firmware (ArkOS, EmuELEC, or Batocera)
- SSH access enabled
- Network connectivity (WiFi or Ethernet)

**Installation Time:** ~15-20 minutes

```bash
# 1. Install Rust (one-time setup)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 2. Cross-compile for ARM (if building on desktop)
rustup target add armv7-unknown-linux-gnueabihf  # For older Anbernics
rustup target add aarch64-unknown-linux-gnu      # For newer Anbernics

# 3. Clone and build
git clone <your-repo> handheld-office
cd handheld-office
./scripts/build.sh

# 4. Configure for your Anbernic model
cp config.toml config_local.toml
# Edit config_local.toml with your device's screen size and capabilities

# 5. Start handheld client
lua scripts/orchestrator.lua start-handheld
```

### Desktop/Laptop (LLM Host)

**Prerequisites:**
- Linux/macOS/Windows with WSL
- 4GB+ RAM for LLM models
- Network access to handheld devices

**Installation Time:** ~30-45 minutes (including model download)

```bash
# 1. Install dependencies
sudo apt update && sudo apt install build-essential lua5.3 curl

# 2. Set up LLM infrastructure
./scripts/setup_llm.sh

# 3. Build components
./scripts/build.sh

# 4. Configure network (edit config.toml)
[network]
daemon_host = "0.0.0.0"  # Listen on all interfaces for LAN access

# 5. Start daemon and LLM service
lua scripts/orchestrator.lua start-daemon
lua scripts/orchestrator.lua start-llm
```

### Raspberry Pi / ARM SBC

**Prerequisites:**
- Raspberry Pi 3B+ or newer
- 2GB+ RAM recommended
- Raspbian/Ubuntu/Arch Linux ARM

**Installation Time:** ~25-35 minutes

```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y

# 2. Install Rust for ARM
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 3. Build (native compilation)
git clone <your-repo> handheld-office
cd handheld-office
./scripts/build.sh

# 4. For Pi as LLM host (optional)
./scripts/setup_llm.sh
# Note: Use smaller models on Pi (7B max recommended)
```

### Steam Deck

**Prerequisites:**
- Desktop mode access
- Developer mode enabled (optional)

**Installation Time:** ~20-25 minutes

```bash
# 1. Switch to desktop mode
# 2. Open terminal

# 3. Install via package manager
sudo pacman -S rust lua

# 4. Build and run
git clone <your-repo> handheld-office
cd handheld-office
./scripts/build.sh

# 5. Create Steam shortcut (optional)
# Point to: lua scripts/orchestrator.lua start-handheld
```

## Configuration Guide

### Basic Configuration (`config.toml`)

The system is highly configurable for different environments:

```toml
# Anbernic RG35XX example
[anbernic.rg35xx]
screen_width = 24
screen_height = 12
cpu_cores = 4
ram_mb = 1024

# Network settings for LAN setup
[network]
daemon_host = "192.168.1.100"  # Your desktop/cluster IP
daemon_port = 8080
```

### Device-Specific Optimizations

**For SD Card Storage (Anbernics):**
```toml
[anbernic]
use_write_buffering = true
sync_interval_seconds = 60
compress_logs = true
```

**For High-RAM Systems (Desktop/Cluster):**
```toml
[llm]
llamacpp_max_tokens = 512
max_concurrent_requests = 10
```

**For Low-Power Devices:**
```toml
[anbernic]
battery_monitoring = true
low_power_mode_threshold = 20
sleep_timeout_minutes = 5
```

### Network Topology Examples

**Single Desktop + Anbernic:**
```
Anbernic (192.168.1.50) ←→ Desktop (192.168.1.100)
                             ↳ Daemon + LLM Service
```

**Multi-Handheld Setup:**
```
Anbernic #1 (192.168.1.50) ←→ Desktop (192.168.1.100)
Anbernic #2 (192.168.1.51) ←↗  ↳ Daemon + LLM Service
Steam Deck  (192.168.1.52) ←↗
```

**Cluster Setup:**
```
Handheld Devices ←→ Router ←→ Pi (Daemon) ←→ Desktop (LLM)
```

## Troubleshooting

### Common Issues

**Build Fails on Anbernic:**
- Ensure sufficient storage (500MB+ free)
- Check that custom firmware supports development tools

**Network Connection Issues:**
- Verify firewall settings (port 8080)
- Check that devices are on same subnet
- Try `ping` between devices first

**LLM Service Not Responding:**
- Check if Ollama/LlamaCPP is running: `ps aux | grep ollama`
- Verify ports: `netstat -tlnp | grep 8000`
- Check model files exist in `models/` directory

**Performance Issues on Handheld:**
- Enable `low_power_mode` in config
- Reduce `screen_width`/`screen_height` values
- Disable `battery_monitoring` if not needed

### Logs and Debugging

All components log to `files/build/`:
- `orchestrator.log` - Build and startup logs
- `daemon_state.json` - Network and message state
- `llm_setup.log` - AI infrastructure setup logs

### Getting Help

The system follows your vision of incremental state saving - if something breaks, check the JSON state files in `files/build/` to understand what was happening before the failure.