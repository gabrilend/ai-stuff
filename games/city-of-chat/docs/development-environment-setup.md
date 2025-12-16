# City of Heroes Development Environment Setup

## Official Requirements (Windows-based)

Based on analysis of `src/src/Readme.md`, the official requirements are:

### Build Tools
- **Visual Studio 2019** (Community Edition supported)
- **clang-format** (integrated with VS 2019)
- **EditorConfig** support (built into VS 2019)

### Database
- **SQL Server 2017** (minimum SQL Server 2008+)
- **SQL Server Management Studio** (SSMS)

### Data Files
Required data archives from https://wiki.ourodev.com/Magnet_Links:
- "Volume 2 Issue 1.1 Server Data"  
- "Volume 2 Issue 1.1 Server Piggs"

### Development Standards
- **Code Style**: Allman brace style, 160 character line width
- **Language Standards**: C/C++, C# support
- **Formatting**: Automated with clang-format
- **Configuration**: EditorConfig for consistent settings

## Linux/Cross-Platform Alternative Setup

Since we're working on Linux, we need equivalent tools:

### Compiler and Build Tools
```bash
# Install GCC/G++ with C++17+ support
sudo apt update
sudo apt install build-essential gcc g++ cmake make

# Install clang-format for code formatting
sudo apt install clang-format

# Install git for version control
sudo apt install git
```

### Database Alternatives
```bash
# PostgreSQL as SQL Server alternative
sudo apt install postgresql postgresql-contrib libpq-dev

# Or MySQL as alternative
sudo apt install mysql-server mysql-client libmysqlclient-dev
```

### Development Environment
```bash
# VS Code with C++ extensions (alternative to VS 2019)
sudo snap install code --classic

# Or use vim/nvim with C++ plugins
sudo apt install vim neovim

# Install EditorConfig support
# (VS Code: install EditorConfig extension)
# (Vim: install editorconfig-vim plugin)
```

### Additional Libraries
Based on source code analysis, likely needed:
```bash
# Common C++ development libraries
sudo apt install libboost-all-dev
sudo apt install libssl-dev
sudo apt install zlib1g-dev
sudo apt install libcurl4-openssl-dev

# Graphics and UI libraries (if needed)
sudo apt install libgl1-mesa-dev
sudo apt install libx11-dev
```

## Current System Analysis

Let's check what we already have installed:
- **OS**: Linux (detected)
- **GCC**: Need to verify version
- **Development Tools**: Need to check availability
- **Database**: Need to install and configure

## Setup Verification Steps

1. **Compiler Test**: Compile a simple C++ program
2. **Build System Test**: Test cmake/make functionality  
3. **Database Test**: Connect to database system
4. **Source Code Test**: Attempt to build CoH source

## Next Steps

1. Install and configure Linux development tools
2. Set up database system (PostgreSQL recommended)
3. Download required data files
4. Test build environment with CoH source
5. Document any compatibility issues or required modifications