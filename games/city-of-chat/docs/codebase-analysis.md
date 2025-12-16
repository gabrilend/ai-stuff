# City of Heroes Codebase Analysis

## Project Structure Overview

**Source Location**: `src/coh-source/` (organized from Source-develop.zip)  
**Project**: Ouroboros - City of Heroes Server  
**Build System**: Visual Studio 2019 (Windows-centric)  
**Language**: Primarily C/C++, some C#  

## Major Server Components

### Core Game Servers
- **MapServer** - Main game world simulation and player interaction
- **DBServer** - Database operations and data persistence
- **AuthServer** - Player authentication and account management  
- **AccountServer** - Account creation and management services

### Specialized Servers
- **AuctionServer** - In-game auction house/market system
- **ChatServer** - Chat and communication systems
- **ArenaServer** - PvP arena and combat systems
- **RaidServer** - Large-group content and raid coordination
- **MissionServer** - Mission/quest system management
- **StatServer** - Player statistics and metrics tracking

### Support Services  
- **QueueServer** - Login queue and server population management
- **TurnstileServer** - Load balancing and player routing
- **ShardMonitor** - Server shard monitoring and health checks
- **ServerMonitor** - Overall server farm monitoring
- **CmdRelay** - Command relay and administrative functions
- **ChatAdmin** - Chat moderation and administrative tools

### Client and Utilities
- **Game** - Client-side game executable components
- **Launcher** - Game launcher and updater
- **Utilities** - Various development and administrative tools

## Build System Analysis

### Windows-Based Build (Official)
- **Primary**: Visual Studio 2019 project files (.vcxproj/.sln)
- **Format**: MSBuild system with individual component projects
- **Dependencies**: Windows SDK, DirectX SDK, SQL Server libraries

### Project Files Structure
```
Component/
├── build/
│   └── vs2019/
│       └── Component.vcxproj
├── src/
│   └── [source files]
└── include/
    └── [header files]
```

### Startup Scripts
- `1-start-servers.bat` - Windows batch script to start server components
- `2-start-game.bat` - Windows batch script to launch client

## External Dependencies (3rdparty/)

### Graphics and Rendering
- **NVIDIA Cg** - GPU shading language support
- **GLEW 2.1.0** - OpenGL Extension Wrangler
- **3dsmax** - 3D Studio Max SDK integration
- **AlienFX SDK** - Hardware lighting effects
- **PhysX** - NVIDIA physics simulation

### Compression and Encoding
- **bzip2 1.0.6** - Data compression
- **zlib-1.2.8** - General purpose compression
- **jpeg-9c** - JPEG image handling
- **jpgdlib-0.93b** - Additional JPEG libraries

### Cryptography and Security
- **cryptopp-8.3** - Cryptography++ library for encryption

### Graphics File Formats
- **freetype-2.1.9** - Font rendering
- **libpng-1.6.37** - PNG image format support
- **libtiff** - TIFF image format support

### Development and Testing
- **UnitTest++** - C++ unit testing framework
- **DoubleFusion** - Unknown/proprietary component

### Networking and Communication
- **WinSock** dependencies (Windows-specific networking)

## Code Style and Standards

### Language Standards
- **C/C++**: Primary implementation language
- **C99/C++17**: Modern language features expected
- **Assembly**: Low-level optimizations in some components

### Formatting Standards
- **Style**: Allman brace style
- **Line Width**: 160 characters
- **Tool**: clang-format with custom configuration
- **Editor**: EditorConfig for consistent settings

### Naming Conventions
- **Variables/Functions**: camelCase
- **Types/Classes**: PascalCase
- **Constants/Macros**: UPPER_SNAKE_CASE
- **Files**: lower_snake_case preferred
- **Private Fields**: trailing underscore (`field_`)

## Linux Porting Considerations

### Major Challenges
1. **Visual Studio Dependencies**: All build files are VS2019-specific
2. **Windows APIs**: Extensive use of Windows-specific libraries
3. **DirectX**: Graphics subsystem dependencies
4. **SQL Server**: Database engine dependencies
5. **WinSock**: Windows networking APIs

### Potential Solutions
1. **Build System**: Create CMake build files as alternatives
2. **Graphics**: OpenGL/Vulkan instead of DirectX
3. **Database**: PostgreSQL instead of SQL Server
4. **Networking**: POSIX sockets instead of WinSock
5. **Platform Abstractions**: Create cross-platform shims

### Dependencies Already Linux-Compatible
- Most 3rdparty libraries have Linux versions
- Cryptography++ has Linux support
- OpenGL/GLEW work on Linux
- Compression libraries (zlib, bzip2) are cross-platform

## Development Requirements Summary

### Windows (Official)
- Visual Studio 2019 Community+
- SQL Server 2017+
- Windows 10+ (recommended)
- DirectX SDK
- Server data files from Ouroboros

### Linux (Proposed Alternative)
- GCC 14+ with C++17 support
- PostgreSQL 16+
- OpenGL development libraries
- Custom build system (CMake)
- Cross-platform networking layer

## Next Steps for Linux Port

1. **Create CMake Build System**: Replace Visual Studio projects
2. **Platform Abstraction Layer**: Abstract Windows-specific APIs
3. **Database Adaptation**: Port SQL Server schemas to PostgreSQL
4. **Graphics Porting**: Replace DirectX with OpenGL/Vulkan
5. **Network Layer**: Replace WinSock with POSIX sockets
6. **Testing Framework**: Validate functionality on Linux

## File Counts and Complexity

```bash
# Component breakdown (estimated)
Core Servers:     ~15 major components
Utility Programs: ~40+ tools and utilities  
3rd Party Libs:   ~30+ external dependencies
Build Projects:   ~60+ individual build targets
```

This is a substantial enterprise-grade MMORPG server codebase requiring significant effort to port to Linux, but the modular architecture and comprehensive 3rdparty library usage suggests it's achievable with systematic effort.