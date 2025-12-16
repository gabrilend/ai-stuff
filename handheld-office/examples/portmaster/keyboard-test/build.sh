#!/bin/bash

# Build script for Radial Keyboard Test Portmaster application
# Builds for ARM targets commonly used in Anbernic handheld devices

set -e  # Exit on any error

echo "🔨 Building Radial Keyboard Test for Portmaster..."
echo "================================================"

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "❌ Error: Rust/Cargo not found. Please install Rust toolchain."
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
cargo clean

# Build for ARM7 (most Anbernic devices)
echo "🏗️ Building for armv7-unknown-linux-gnueabihf..."
if command -v rustup &> /dev/null; then
    rustup target add armv7-unknown-linux-gnueabihf
fi

cargo build --release --target armv7-unknown-linux-gnueabihf

# Check if build succeeded
if [ -f "target/armv7-unknown-linux-gnueabihf/release/radial-test" ]; then
    echo "✅ ARM7 build successful!"
    
    # Copy binary to root for easy deployment
    cp target/armv7-unknown-linux-gnueabihf/release/radial-test ./radial-test-arm7
    
    # Show binary info
    echo "📊 Binary information:"
    ls -lh radial-test-arm7
    file radial-test-arm7
else
    echo "❌ ARM7 build failed!"
fi

# Build for ARM64 (newer devices)
echo "🏗️ Building for aarch64-unknown-linux-gnu..."
if command -v rustup &> /dev/null; then
    rustup target add aarch64-unknown-linux-gnu
fi

cargo build --release --target aarch64-unknown-linux-gnu

# Check if build succeeded  
if [ -f "target/aarch64-unknown-linux-gnu/release/radial-test" ]; then
    echo "✅ ARM64 build successful!"
    
    # Copy binary to root for easy deployment
    cp target/aarch64-unknown-linux-gnu/release/radial-test ./radial-test-arm64
    
    # Show binary info
    echo "📊 Binary information:"
    ls -lh radial-test-arm64
    file radial-test-arm64
else
    echo "❌ ARM64 build failed!"
fi

# Create deployment package
echo "📦 Creating deployment package..."
mkdir -p deploy/radial-keyboard-test

# Copy necessary files
cp radial-test-arm* deploy/radial-keyboard-test/ 2>/dev/null || echo "⚠️ Some binaries missing"
cp portmaster.json deploy/radial-keyboard-test/
cp controls.cfg deploy/radial-keyboard-test/
cp README.md deploy/radial-keyboard-test/

# Create deployment script
cat > deploy/radial-keyboard-test/install.sh << 'EOF'
#!/bin/bash
# Automatic installation script for Portmaster

echo "Installing Radial Keyboard Test..."

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    armv7l|armv6l)
        BINARY="radial-test-arm7"
        ;;
    aarch64|arm64)
        BINARY="radial-test-arm64" 
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

if [ ! -f "$BINARY" ]; then
    echo "Binary for $ARCH not found!"
    exit 1
fi

# Copy binary with standard name
cp "$BINARY" radial-test
chmod +x radial-test

echo "Installation complete! Launch from Portmaster."
EOF

chmod +x deploy/radial-keyboard-test/install.sh

# Create archive for easy transfer
cd deploy
tar czf radial-keyboard-test.tar.gz radial-keyboard-test/
cd ..

echo "🎉 Build complete!"
echo "📁 Deployment files in: deploy/radial-keyboard-test/"
echo "📦 Archive created: deploy/radial-keyboard-test.tar.gz"
echo ""
echo "📋 Deployment instructions:"
echo "1. Copy deploy/radial-keyboard-test/ to Portmaster apps directory"
echo "2. Run ./install.sh on target device"
echo "3. Launch from Portmaster > Applications > Utilities"