# City of Heroes External Dependencies

## Complete 3rdparty Library Inventory

Based on analysis of `src/coh-source/3rdparty/` directory:

### Graphics and Rendering (7 libraries)
- **3dsmax** - 3D Studio Max SDK integration
- **AlienFX SDK** - Hardware lighting effects (gaming peripherals)
- **cg** - NVIDIA Cg shading language support
- **freetype-2.1.9** - Font rendering and typography
- **glew-2.1.0** - OpenGL Extension Wrangler Library
- **PhysX** - NVIDIA physics simulation engine
- **ogg** - Ogg Vorbis audio codec

### Image and Media Processing (8 libraries)
- **jpeg-9c** - JPEG image compression/decompression
- **jpgdlib-0.93b** - Additional JPEG processing utilities
- **libpng-1.6.37** - PNG image format support
- **libtiff** - TIFF image format support
- **targa** - TGA image format support
- **devil** - Developer's Image Library (multi-format)
- **vorbis** - Ogg Vorbis audio decoding
- **SDL** - Simple DirectMedia Layer (multimedia)

### Compression and Data (4 libraries)
- **bzip2-1.0.6** - High-quality data compressor
- **zlib-1.2.8** - General purpose data compression
- **lzo** - Real-time data compression
- **minizip** - ZIP file format handling

### Cryptography and Security (2 libraries)
- **cryptopp-8.3** - Cryptography++ encryption library
- **openssl** - SSL/TLS cryptographic protocols

### Development and Testing (3 libraries)
- **UnitTest++** - C++ unit testing framework
- **gtest** - Google Test framework
- **benchmark** - Performance benchmarking tools

### Networking and Communication (3 libraries)
- **curl** - URL transfer library
- **websockets** - WebSocket communication protocol
- **protobuf** - Protocol Buffers serialization

### Utility Libraries (4 libraries)
- **boost** - Comprehensive C++ libraries collection
- **expat** - XML parsing library
- **sqlite** - Embedded SQL database engine
- **DoubleFusion** - Proprietary/unknown component

## Build Dependencies by Component

### Core Server Dependencies
**Required by most server components:**
- cryptopp (authentication, encryption)
- boost (utilities, networking)
- zlib (compression)
- sqlite (embedded data storage)

### Graphics-Heavy Components (Game client, utilities)
**Required by Game/, Utilities/:**
- GLEW (OpenGL extensions)
- PhysX (physics simulation)
- freetype (font rendering)
- Image libraries (JPEG, PNG, TIFF)
- Cg shaders (GPU programming)

### Specialized Server Dependencies
**MapServer, GameServer:**
- PhysX (world physics)
- All compression libraries
- Image processing for dynamic content

**AuthServer, AccountServer:**
- cryptopp (password hashing)
- openssl (secure communications)
- sqlite (session storage)

## Linux Porting Assessment

### ✅ Linux-Native Libraries (Good compatibility)
- **boost** - Full Linux support
- **cryptopp** - Cross-platform
- **zlib, bzip2, lzo** - Standard on Linux
- **openssl** - Native Linux library
- **sqlite** - Cross-platform
- **freetype** - Standard Linux font library
- **GLEW** - Available via package managers
- **curl** - Native Linux library
- **expat** - Standard XML parser
- **protobuf** - Google-maintained, Linux-native

### ⚠️ Needs Linux Alternatives
- **PhysX** - NVIDIA provides Linux version
- **Cg** - Deprecated, replace with GLSL
- **SDL** - Available on Linux
- **Image libraries** - Most have Linux versions

### ❌ Windows-Specific (Major concerns)
- **3dsmax SDK** - Windows-only, may need removal/replacement
- **AlienFX SDK** - Windows gaming peripheral API
- **DoubleFusion** - Unknown proprietary component

## Dependency Build Strategy for Linux

### Phase 1: Core Dependencies (our build script covers)
```bash
# Already implemented in scripts/build_dependencies.sh
- openssl
- zlib  
- boost (planned)
- postgresql (SQL Server replacement)
```

### Phase 2: Additional Required Libraries
```bash
# Need to add to build script:
- cryptopp
- sqlite
- freetype
- curl
- expat
```

### Phase 3: Graphics Dependencies
```bash
# For graphics components:
- GLEW (via package manager or source)
- PhysX (download Linux version)
- Image libraries (JPEG, PNG, TIFF)
```

### Phase 4: Replace/Remove Windows-Specific
```bash
# Components to handle:
- Remove 3dsmax SDK dependencies
- Replace AlienFX with generic RGB API
- Replace Cg shaders with GLSL
```

## Build Script Enhancement Plan

Extend `scripts/build_dependencies.sh` to include:

1. **Core Libraries**: cryptopp, sqlite, freetype, curl, expat
2. **Image Processing**: libjpeg, libpng, libtiff  
3. **Compression**: Additional LZO if needed
4. **Graphics**: GLEW, PhysX Linux version
5. **Audio**: Ogg Vorbis libraries

## Total Dependency Count: 29 libraries
- **Linux Compatible**: ~22 libraries (76%)
- **Needs Alternatives**: ~4 libraries (14%) 
- **Windows-Specific**: ~3 libraries (10%)

The majority of dependencies are Linux-compatible, making the porting effort achievable with systematic replacement of Windows-specific components.