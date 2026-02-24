# ai-stuff monorepo sandbox container
# Provides LuaJIT environment with GPU (Vulkan/OpenGL) and X11 graphics support
# Supports NVIDIA, AMD, Intel GPUs, or software rendering fallback
#
# Build: docker build -t ai-stuff-sandbox .
# Run:   See docker-compose.yml or docker-run.sh for proper invocation

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
# - LuaJIT and dev headers for Lua projects
# - Build tools for compiling C libraries
# - Graphics stack: Vulkan, OpenGL, SDL2, GLFW (vendor-agnostic)
# - X11 libs for display forwarding
# - VNC server as fallback for non-Linux hosts
RUN apt-get update && apt-get install -y \
    # Lua
    luajit \
    libluajit-5.1-dev \
    luarocks \
    # Build tools
    build-essential \
    cmake \
    pkg-config \
    git \
    # Graphics - Vulkan (vendor-agnostic)
    vulkan-tools \
    libvulkan1 \
    libvulkan-dev \
    vulkan-validationlayers \
    # Mesa drivers - provides software fallback and AMD/Intel support
    mesa-vulkan-drivers \
    mesa-va-drivers \
    mesa-utils \
    # Graphics - OpenGL/SDL/GLFW
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libegl1-mesa-dev \
    libsdl2-dev \
    libsdl2-image-dev \
    libsdl2-ttf-dev \
    libglfw3-dev \
    libglew-dev \
    # X11 forwarding support
    libx11-dev \
    libxrandr-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxi-dev \
    x11-apps \
    # VNC fallback (for non-Linux hosts)
    tigervnc-standalone-server \
    tigervnc-common \
    novnc \
    websockify \
    # Window manager for VNC sessions
    openbox \
    # Utilities
    curl \
    wget \
    unzip \
    htop \
    vim \
    # Networking libs (for luasocket etc)
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for safety
# Using UID 1000 to match typical host user for X11 permissions
RUN useradd -m -u 1000 -s /bin/bash sandbox
RUN echo 'sandbox ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set up workspace
WORKDIR /workspace

# Copy the monorepo
# Use .dockerignore to exclude large/unnecessary files
COPY --chown=sandbox:sandbox . /workspace

# Copy GPU detection and setup scripts
COPY --chown=sandbox:sandbox docker-scripts/ /home/sandbox/scripts/
RUN chmod +x /home/sandbox/scripts/*.sh

# Set library paths for Lua
ENV LUA_PATH="/workspace/libs/lua/?.lua;/workspace/my-libs/?.lua;/workspace/libs/lua/?/init.lua;;"
ENV LUA_CPATH="/workspace/libs/lua/?.so;/workspace/libs/c/?.so;;"

# VNC configuration (used when DISPLAY is not set externally)
ENV VNC_PORT=5901
ENV NOVNC_PORT=6080

# Switch to non-root user
USER sandbox

# Create VNC password file (password: sandbox)
RUN mkdir -p ~/.vnc && \
    echo "sandbox" | vncpasswd -f > ~/.vnc/passwd && \
    chmod 600 ~/.vnc/passwd

# VNC startup script
RUN echo '#!/bin/bash\n\
export DISPLAY=:1\n\
vncserver :1 -geometry 1920x1080 -depth 24\n\
websockify --web=/usr/share/novnc/ $NOVNC_PORT localhost:$VNC_PORT &\n\
echo "VNC available at localhost:$VNC_PORT"\n\
echo "noVNC (browser) available at http://localhost:$NOVNC_PORT/vnc.html"\n\
exec openbox-session' > ~/start-vnc.sh && chmod +x ~/start-vnc.sh

# Default command: run GPU detection then bash
CMD ["/home/sandbox/scripts/entrypoint.sh"]
