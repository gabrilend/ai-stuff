# UT2K4 Symbeline Rumble - Build Configuration
#
# Simple key=value configuration file parsed by build scripts
# Edit values below to configure your development environment
#
# Notes:
#   - Lines starting with # are comments
#   - Blank lines are ignored
#   - Format: KEY=value (no spaces around =)
#   - Paths can use ${PROJECT_DIR} which auto-expands to project root

# UT2004 installation directory
# Default uses project-local installation (git-ignored)
# Override: Create config.local with custom UT2004_DIR value
UT2004_DIR=${PROJECT_DIR}/UT2004

# Package name (must match directory in UT2004 installation)
PACKAGE_NAME=SymbelineRumble

# Main mutator class name (without package prefix)
MUTATOR_CLASS=SR_SymbelineRumbleMutator

# Version information
VERSION=0.1.0-phase1
