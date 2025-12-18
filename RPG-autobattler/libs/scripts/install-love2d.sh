#!/bin/bash
# install-love2d.sh
# Installs Love2D if not already present

# -- {{{ install-love2d
# Set the directory to the script's directory (following user instructions)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow override via command line argument
if [ $# -eq 1 ]; then
    DIR="$1"
fi

echo "Checking Love2D installation..."

# Check if Love2D is already installed
if command -v love &> /dev/null; then
    love_version=$(love --version 2>/dev/null || echo "Unknown version")
    echo "Love2D is already installed: $love_version"
    exit 0
fi

echo "Love2D not found. Attempting to install..."

# Detect the operating system
if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    echo "Detected Debian/Ubuntu system"
    echo "Installing Love2D via apt..."
    
    sudo apt-get update
    sudo apt-get install -y love
    
elif [ -f /etc/redhat-release ]; then
    # RedHat/CentOS/Fedora
    echo "Detected RedHat-based system"
    
    if command -v dnf &> /dev/null; then
        echo "Installing Love2D via dnf..."
        sudo dnf install -y love
    elif command -v yum &> /dev/null; then
        echo "Installing Love2D via yum..."
        sudo yum install -y love
    else
        echo "No suitable package manager found."
        exit 1
    fi
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo "Detected macOS"
    
    if command -v brew &> /dev/null; then
        echo "Installing Love2D via Homebrew..."
        brew install love
    else
        echo "Homebrew not found. Please install it first or download Love2D manually from:"
        echo "https://love2d.org/"
        exit 1
    fi
    
else
    echo "Unsupported operating system or package manager not found."
    echo "Please install Love2D manually from: https://love2d.org/"
    echo ""
    echo "Installation instructions:"
    echo "1. Visit https://love2d.org/"
    echo "2. Download the appropriate version for your system"
    echo "3. Follow the installation instructions for your OS"
    exit 1
fi

# Verify installation
echo ""
echo "Verifying Love2D installation..."

if command -v love &> /dev/null; then
    love_version=$(love --version 2>/dev/null || echo "Unknown version")
    echo "✓ Love2D successfully installed: $love_version"
else
    echo "✗ Love2D installation failed or not in PATH"
    echo "You may need to:"
    echo "1. Restart your terminal"
    echo "2. Add Love2D to your PATH manually"
    echo "3. Install Love2D manually from https://love2d.org/"
    exit 1
fi
# -- }}}