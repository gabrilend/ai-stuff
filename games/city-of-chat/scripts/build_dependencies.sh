#!/bin/bash
set -euo pipefail

# {{{ build_dependencies
# City of Heroes dependencies build script - Everything from source, all local
# Builds PostgreSQL, Boost, and other dependencies for CoH server

DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/city-of-chat}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
INSTALL_DIR="${PROJECT_DIR}/libs"
DOWNLOADS_DIR="${PROJECT_DIR}/downloads"
LOG_FILE="${PROJECT_DIR}/build_deps.log"

# {{{ cleanup
cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf "${BUILD_DIR}"
}
trap cleanup EXIT
# }}}

# {{{ logging_setup
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== CoH Dependencies build started at $(date) ==="
echo "Build directory: $BUILD_DIR"
echo "Install directory: $INSTALL_DIR"

# Create directories
mkdir -p "$BUILD_DIR" "$INSTALL_DIR" "$DOWNLOADS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
# }}}

# {{{ download_file
download_file() {
    local url="$1"
    local filename="$2"
    local filepath="${DOWNLOADS_DIR}/${filename}"
    
    if [[ -f "$filepath" ]]; then
        log_info "Using cached $filename"
        return 0
    fi
    
    log_info "Downloading $filename..."
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$filepath" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$filepath" "$url"
    else
        log_error "Neither curl nor wget found"
        exit 1
    fi
}
# }}}

# {{{ build_zlib
build_zlib() {
    log_info "Building zlib from source..."
    
    local zlib_version="1.3.1"
    local zlib_tarball="zlib-${zlib_version}.tar.gz"
    local zlib_url="https://github.com/madler/zlib/releases/download/v${zlib_version}/${zlib_tarball}"
    local zlib_prefix="${INSTALL_DIR}/zlib"
    
    # Check if already built
    if [[ -f "${zlib_prefix}/lib/libz.a" ]]; then
        log_info "zlib already built"
        return 0
    fi
    
    # Download zlib source
    download_file "$zlib_url" "$zlib_tarball"
    
    # Extract and build
    local zlib_src_dir="${BUILD_DIR}/zlib-${zlib_version}"
    rm -rf "$zlib_src_dir"
    
    log_info "Extracting zlib source..."
    tar -xf "${DOWNLOADS_DIR}/${zlib_tarball}" -C "$BUILD_DIR"
    
    cd "$zlib_src_dir"
    
    log_info "Configuring zlib..."
    ./configure --prefix="$zlib_prefix"
    
    log_info "Building zlib..."
    make -j"$(nproc)"
    
    log_info "Installing zlib..."
    make install
    
    log_info "zlib built successfully"
    cd "$PROJECT_DIR"
}
# }}}

# {{{ build_openssl
build_openssl() {
    log_info "Building OpenSSL from source..."
    
    local openssl_version="3.0.15"
    local openssl_tarball="openssl-${openssl_version}.tar.gz"
    local openssl_url="https://www.openssl.org/source/${openssl_tarball}"
    local openssl_prefix="${INSTALL_DIR}/openssl"
    
    # Check if already built
    if [[ -f "${openssl_prefix}/lib/libssl.a" ]]; then
        log_info "OpenSSL already built"
        return 0
    fi
    
    # Download OpenSSL source
    download_file "$openssl_url" "$openssl_tarball"
    
    # Extract and build
    local openssl_src_dir="${BUILD_DIR}/openssl-${openssl_version}"
    rm -rf "$openssl_src_dir"
    
    log_info "Extracting OpenSSL source..."
    tar -xf "${DOWNLOADS_DIR}/${openssl_tarball}" -C "$BUILD_DIR"
    
    cd "$openssl_src_dir"
    
    log_info "Configuring OpenSSL..."
    ./Configure linux-x86_64 --prefix="$openssl_prefix" --openssldir="$openssl_prefix/ssl"
    
    log_info "Building OpenSSL..."
    make -j"$(nproc)"
    
    log_info "Installing OpenSSL..."
    make install
    
    log_info "OpenSSL built successfully"
    cd "$PROJECT_DIR"
}
# }}}

# {{{ build_boost
build_boost() {
    log_info "Building Boost from source..."
    
    local boost_version="1.84.0"
    local boost_version_underscore="${boost_version//./_}"
    local boost_tarball="boost_${boost_version_underscore}.tar.gz"
    local boost_url="https://archives.boost.io/release/${boost_version}/source/${boost_tarball}"
    local boost_prefix="${INSTALL_DIR}/boost"
    
    # Check if already built
    if [[ -f "${boost_prefix}/lib/libboost_system.a" ]]; then
        log_info "Boost already built"
        return 0
    fi
    
    # Download Boost source
    download_file "$boost_url" "$boost_tarball"
    
    # Extract and build
    local boost_src_dir="${BUILD_DIR}/boost_${boost_version_underscore}"
    rm -rf "$boost_src_dir"
    
    log_info "Extracting Boost source..."
    tar -xf "${DOWNLOADS_DIR}/${boost_tarball}" -C "$BUILD_DIR"
    
    cd "$boost_src_dir"
    
    log_info "Bootstrapping Boost..."
    ./bootstrap.sh --prefix="$boost_prefix"
    
    log_info "Building Boost (this may take a while)..."
    ./b2 -j"$(nproc)" --prefix="$boost_prefix" install
    
    log_info "Boost built successfully"
    cd "$PROJECT_DIR"
}
# }}}

# {{{ build_postgresql
build_postgresql() {
    log_info "Building PostgreSQL from source..."
    
    local pg_version="16.4"
    local pg_tarball="postgresql-${pg_version}.tar.gz"
    local pg_url="https://ftp.postgresql.org/pub/source/v${pg_version}/${pg_tarball}"
    local pg_prefix="${INSTALL_DIR}/postgresql"
    local zlib_prefix="${INSTALL_DIR}/zlib"
    local openssl_prefix="${INSTALL_DIR}/openssl"
    
    # Check if already built
    if [[ -x "${pg_prefix}/bin/postgres" ]]; then
        log_info "PostgreSQL already built"
        return 0
    fi
    
    # Download PostgreSQL source
    download_file "$pg_url" "$pg_tarball"
    
    # Extract and build
    local pg_src_dir="${BUILD_DIR}/postgresql-${pg_version}"
    rm -rf "$pg_src_dir"
    
    log_info "Extracting PostgreSQL source..."
    tar -xf "${DOWNLOADS_DIR}/${pg_tarball}" -C "$BUILD_DIR"
    
    cd "$pg_src_dir"
    
    log_info "Configuring PostgreSQL..."
    ./configure \
        --prefix="$pg_prefix" \
        --with-openssl \
        --with-zlib \
        --with-readline \
        --enable-thread-safety \
        CPPFLAGS="-I${openssl_prefix}/include -I${zlib_prefix}/include" \
        LDFLAGS="-L${openssl_prefix}/lib -L${zlib_prefix}/lib"
    
    log_info "Building PostgreSQL..."
    make -j"$(nproc)"
    
    log_info "Installing PostgreSQL..."
    make install
    
    log_info "PostgreSQL built successfully"
    cd "$PROJECT_DIR"
}
# }}}

# {{{ create_environment_script
create_environment_script() {
    log_info "Creating environment setup script..."
    
    local env_script="${PROJECT_DIR}/scripts/setup_env.sh"
    
    cat > "$env_script" << EOF
#!/bin/bash
# {{{ setup_env
# Environment setup for City of Heroes development

DIR="\${1:-${PROJECT_DIR}}"
export COH_LIBS_DIR="\${DIR}/libs"

# Add library paths
export PATH="\${COH_LIBS_DIR}/postgresql/bin:\${COH_LIBS_DIR}/openssl/bin:\$PATH"
export LD_LIBRARY_PATH="\${COH_LIBS_DIR}/postgresql/lib:\${COH_LIBS_DIR}/openssl/lib:\${COH_LIBS_DIR}/boost/lib:\${COH_LIBS_DIR}/zlib/lib:\$LD_LIBRARY_PATH"

# C++ build environment
export CPPFLAGS="-I\${COH_LIBS_DIR}/postgresql/include -I\${COH_LIBS_DIR}/openssl/include -I\${COH_LIBS_DIR}/boost/include -I\${COH_LIBS_DIR}/zlib/include \$CPPFLAGS"
export LDFLAGS="-L\${COH_LIBS_DIR}/postgresql/lib -L\${COH_LIBS_DIR}/openssl/lib -L\${COH_LIBS_DIR}/boost/lib -L\${COH_LIBS_DIR}/zlib/lib \$LDFLAGS"

# Database setup
export PGDATA="\${DIR}/data/postgresql"
export PGHOST="localhost"
export PGPORT="5432"

echo "City of Heroes development environment configured"
echo "Libraries installed in: \$COH_LIBS_DIR"
echo ""
echo "To initialize PostgreSQL database:"
echo "  \${COH_LIBS_DIR}/postgresql/bin/initdb -D \$PGDATA"
echo ""
echo "To start PostgreSQL:"
echo "  \${COH_LIBS_DIR}/postgresql/bin/pg_ctl -D \$PGDATA -l \${DIR}/data/postgresql.log start"
echo ""
# }}}
EOF
    
    chmod +x "$env_script"
    log_info "Environment script created: $env_script"
}
# }}}

# {{{ interactive_mode
interactive_mode() {
    echo "=== CoH Dependencies Build Tool ==="
    echo ""
    echo "Available build options:"
    echo "1) Build all dependencies"
    echo "2) Build zlib only"
    echo "3) Build OpenSSL only"
    echo "4) Build Boost only"
    echo "5) Build PostgreSQL only"
    echo "6) Create environment script only"
    echo ""
    read -p "Enter choice (1-6): " choice
    
    case $choice in
        1)
            build_zlib
            build_openssl
            build_boost
            build_postgresql
            create_environment_script
            ;;
        2)
            build_zlib
            ;;
        3)
            build_openssl
            ;;
        4)
            build_boost
            ;;
        5)
            build_postgresql
            ;;
        6)
            create_environment_script
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
}
# }}}

# {{{ main
main() {
    log_info "Starting CoH dependencies build process..."
    
    # Check prerequisites
    if ! command -v gcc >/dev/null 2>&1; then
        log_error "GCC is required"
        exit 1
    fi
    
    if ! command -v make >/dev/null 2>&1; then
        log_error "make is required"
        exit 1
    fi
    
    # Check for interactive flag
    if [ "$1" = "-I" ] 2>/dev/null; then
        interactive_mode
    else
        # Build all dependencies
        build_zlib
        build_openssl
        build_boost
        build_postgresql
        create_environment_script
    fi
    
    log_info "Build completed successfully!"
    echo
    echo "Dependencies installed in: $INSTALL_DIR"
    echo ""
    echo "To set up the environment:"
    echo "  source ${PROJECT_DIR}/scripts/setup_env.sh"
    echo ""
}

main "$@"
# }}}
# }}}