# Handheld Office Deployment Guide 🎮

Complete deployment instructions for running on Anbernic devices and various other systems.

## Device-Specific Deployment Times

|       Device Type        | Installation Time |        Notes            |
|--------------------------|-----------.-------'-------------------------|
| **Anbernic RG35XX/351P** | 15-20 min | ARM32, Custom firmware required |
| **Anbernic RG552/405M**  | 15-20 min | ARM64, More powerful            |
| **Desktop/Laptop**       | 30-45 min | Includes LLM model download     |
| **Raspberry Pi**         | 25-35 min | Native ARM compilation          |
| **Steam Deck**           | 20-25 min | Via desktop mode                |

## Anbernic Deployment (Detailed) 🕹️

### Supported Models
- RG35XX (all variants)
- RG351P/M/V/MP
- RG552
- RG405M/V
- RG353P/M/V
- And most other Anbernic devices! But only the ones that run Linux.

### Prerequisites

1. **Custom Firmware** (choose one):
   - ArkOS (recommended for RG351P/RG552)
   - EmuELEC (good for older models)
   - Batocera (universal but heavier)
   - JelOS (lightweight option)

2. **Network Setup**:
   ```bash
   # Enable SSH in your firmware settings
   # Connect to WiFi or use Ethernet adapter
   # Note your device IP: Settings → Network → IP Address
   ```

3. **Storage Requirements**:
   - 500MB free space on internal storage
   - Class 10 SD card recommended
   - Consider using SSD for faster builds

### Step-by-Step Installation

```bash
# 1. SSH into your Anbernic device
ssh root@192.168.1.50  # Use your device's IP

# 2. Install Rust toolchain (one-time setup)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 3. Install additional dependencies
# For ArkOS/Ubuntu-based:
apt update && apt install build-essential lua5.3 git

# For EmuELEC/LibreELEC:
opkg update && opkg install git lua

# 4. Clone the project
cd /storage  # or wherever you have write access
git clone https://github.com/your-username/handheld-office.git
cd handheld-office

# 5. Configure for your specific Anbernic model
cp config.toml config_local.toml

# Edit with your device specs:
nano config_local.toml
# Set [anbernic.your_model] section appropriately

# 6. Build the project
./scripts/build.sh

# 7. Test the handheld client
lua scripts/orchestrator.lua start-handheld
```

### Anbernic-Specific Optimizations

**For SD Card Longevity:**
```toml
[anbernic]
use_write_buffering = true
sync_interval_seconds = 60
compress_logs = true
```

**For Battery Life:**
```toml
[anbernic]
battery_monitoring = true
low_power_mode_threshold = 20
sleep_timeout_minutes = 5
```

**Model-Specific Settings:**

```toml
# RG35XX (ARM32, 1GB RAM)
[anbernic.rg35xx]
screen_width = 24
screen_height = 12
cpu_cores = 4
ram_mb = 1024

# RG552 (ARM64, 2GB RAM) 
[anbernic.rg552]
screen_width = 30
screen_height = 15
cpu_cores = 8
ram_mb = 2048

# RG405M (ARM64, 4GB RAM)
[anbernic.rg405m]
screen_width = 25
screen_height = 12
cpu_cores = 8
ram_mb = 4096
```

### Creating Boot Scripts for Anbernic

**Auto-start on boot** (optional):
```bash
# Create startup script
cat > /storage/roms/ports/handheld-office.sh << 'EOF'
#!/bin/bash
cd /storage/handheld-office
lua scripts/orchestrator.lua start-handheld
EOF

chmod +x /storage/roms/ports/handheld-office.sh
```

## Desktop/Cluster LLM Host Setup

### Hardware Requirements

|  Component  | Minimum | Recommended |    Optimal   |
|-------------|---------|-------------|--------------|
|   **RAM**   |    4GB  |    16GB     |    32GB+     |
| **Storage** |   20GB  |   100GB SSD |   500GB NVMe |
|   **CPU**   | 4 cores |   8 cores   |   16+ cores  |
|   **GPU**   |  None   |  RTX 3060   |   RTX 4090   |

### Installation

```bash
# 1. Install system dependencies
# Ubuntu/Debian:
sudo apt update && sudo apt install build-essential lua5.3 curl git

# Arch Linux:
sudo pacman -S base-devel lua rust git

# macOS:
brew install lua rust git

# 2. Clone and build
git clone https://github.com/your-username/handheld-office.git
cd handheld-office
./scripts/build.sh

# 3. Set up LLM infrastructure
./scripts/setup_llm.sh

# 4. Configure for LAN access
nano config.toml
# Set daemon_host = "0.0.0.0" to listen on all interfaces

# 5. Start services
lua scripts/orchestrator.lua start-daemon
lua scripts/orchestrator.lua start-llm
```

### LLM Backend Options

**Ollama (Easiest)**:
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Download models
ollama pull llama2          # 7B model (~4GB)
ollama pull codellama       # Code-focused
ollama pull mistral         # Fast alternative
```

**LlamaCPP (Most Control)**:
```bash
# Install llama-cpp-python
pip install llama-cpp-python[server]

# Download GGUF models from Hugging Face
wget https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGUF/resolve/main/llama-2-7b-chat.q4_0.gguf

# Start server
python -m llama_cpp.server --model llama-2-7b-chat.q4_0.gguf --port 8000
```

**KoboldCPP (Gaming-Focused)**:
```bash
# Download from GitHub releases
wget https://github.com/LostRuins/koboldcpp/releases/latest/download/koboldcpp-linux-x64
chmod +x koboldcpp-linux-x64

# Run with model
./koboldcpp-linux-x64 --model your-model.gguf --port 5001
```

## Cross-Compilation Guide

### Building for Anbernic on Desktop

```bash
# Install cross-compilation targets
rustup target add armv7-unknown-linux-gnueabihf  # ARM32 (RG35XX, older models)
rustup target add aarch64-unknown-linux-gnu      # ARM64 (RG552, newer models)

# Cross-compile
cargo build --release --target armv7-unknown-linux-gnueabihf --bin handheld
cargo build --release --target aarch64-unknown-linux-gnu --bin handheld

# Copy to device
scp target/armv7-unknown-linux-gnueabihf/release/handheld root@192.168.1.50:/storage/handheld-office/
```

### Docker Deployment (Advanced)

```dockerfile
# Dockerfile for consistent builds
FROM rust:1.70 as builder

RUN apt-get update && apt-get install -y \
    gcc-arm-linux-gnueabihf \
    gcc-aarch64-linux-gnu

WORKDIR /app
COPY . .

RUN rustup target add armv7-unknown-linux-gnueabihf aarch64-unknown-linux-gnu
RUN cargo build --release --target armv7-unknown-linux-gnueabihf
RUN cargo build --release --target aarch64-unknown-linux-gnu

FROM debian:bullseye-slim
RUN apt-get update && apt-get install -y lua5.3
COPY --from=builder /app/target/release/ /usr/local/bin/
COPY --from=builder /app/scripts/ /opt/handheld-office/scripts/
CMD ["lua", "/opt/handheld-office/scripts/orchestrator.lua", "run"]
```

## Network Configuration Examples

### Home Network Setup

```
Router (192.168.1.1)
├── Desktop (192.168.1.100) - LLM Host + Daemon
├── Anbernic #1 (192.168.1.50) - RG35XX
├── Anbernic #2 (192.168.1.51) - RG552
└── Laptop (192.168.1.102) - Development
```

**Configuration:**
```toml
# On all devices
[network]
daemon_host = "192.168.1.100"
daemon_port = 8080
```

### Isolated Gaming Network

```
Dedicated Router
├── Raspberry Pi (192.168.10.1) - Daemon
├── Desktop (192.168.10.2) - LLM Host
└── Handhelds (192.168.10.10-19) - Gaming devices
```

**Benefits:**
- No internet distractions
- Lower latency
- Dedicated bandwidth for AI requests

## Performance Tuning

### For Anbernic Devices

```toml
[handheld]
# Reduce screen complexity for better performance
screen_width = 20
screen_height = 8
max_display_lines = 10

# Optimize input responsiveness
input_repeat_delay_ms = 200
input_repeat_rate_ms = 80

[build]
# Faster builds on limited storage
parallel_build_jobs = 2  # Don't overwhelm weak CPU
```

### For High-End Systems

```toml
[llm]
# Use more resources
llamacpp_max_tokens = 1024
max_concurrent_requests = 20

[build]
parallel_build_jobs = 16  # Use all cores
```

## Troubleshooting by Device

### Anbernic-Specific Issues

**"Permission denied" during build:**
```bash
# Remount with write permissions
mount -o remount,rw /
```

**"No space left on device":**
```bash
# Clean up package cache
apt clean
# Or use external storage
export CARGO_TARGET_DIR=/storage/tmp/target
```

**WiFi connection drops:**
```bash
# Add to config
[network]
auto_reconnect = true
max_reconnect_attempts = 10
heartbeat_interval_seconds = 60
```

### Desktop Issues

**Firewall blocking connections:**
```bash
# Ubuntu/Debian
sudo ufw allow 8080
sudo ufw allow 8000
sudo ufw allow 5001

# CentOS/RHEL
sudo firewall-cmd --add-port=8080/tcp --permanent
sudo firewall-cmd --reload
```

**LLM models not loading:**
```bash
# Check model file permissions
ls -la models/
chmod 644 models/*.gguf

# Verify model format
file models/your-model.gguf
```

## Maintenance and Updates

### Auto-Update Script

```bash
#!/bin/bash
# update_handheld_office.sh

cd /storage/handheld-office
git pull origin main

# Backup current config
cp config_local.toml config_local.toml.bak

# Rebuild
./scripts/build.sh

# Restart services
lua scripts/orchestrator.lua stop
sleep 2
lua scripts/orchestrator.lua run
```

### Monitoring and Health Checks

```bash
# Check system status
lua scripts/orchestrator.lua status

# View logs
tail -f files/build/orchestrator.log

# Check network connectivity
ping 192.168.1.100  # Your LLM host

# Monitor resource usage
htop
df -h  # Check disk space
```

This deployment guide ensures your Handheld Office system runs smoothly on any Anbernic device and integrates perfectly with your LAN-based AI infrastructure! 🎮✨
