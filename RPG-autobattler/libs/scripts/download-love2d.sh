#!/bin/bash
# download-love2d.sh
# Downloads Love2D AppImage locally

# -- {{{ download-love2d
# Set the directory to the script's directory (following user instructions)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow override via command line argument
if [ $# -eq 1 ]; then
    DIR="$1"
fi

# Navigate to love2d directory
cd "$DIR/../love2d"

LOVE2D_VERSION="11.5"
DOWNLOAD_URL="https://github.com/love2d/love/releases/download/${LOVE2D_VERSION}/love-${LOVE2D_VERSION}-x86_64.AppImage"

echo "Downloading Love2D v${LOVE2D_VERSION} AppImage..."
echo "URL: $DOWNLOAD_URL"

# Download Love2D AppImage
wget "$DOWNLOAD_URL" -O "love-${LOVE2D_VERSION}-x86_64.AppImage"

if [ $? -eq 0 ]; then
    echo "Download successful!"
    
    # Make executable
    chmod +x "love-${LOVE2D_VERSION}-x86_64.AppImage"
    
    # Test the installation
    echo "Testing Love2D..."
    if "./love-${LOVE2D_VERSION}-x86_64.AppImage" --version; then
        echo "✓ Love2D download successful!"
        echo "AppImage saved as: $(pwd)/love-${LOVE2D_VERSION}-x86_64.AppImage"
    else
        echo "✗ Love2D test failed"
        exit 1
    fi
else
    echo "Failed to download Love2D AppImage"
    exit 1
fi
# -- }}}