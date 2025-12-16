# Issue #007: Missing Directories Referenced in Configuration

## Description

The configuration file references several directories that don't exist in the project structure.

## Documentation States

**In config.toml lines 88-90:**
```toml
[paths]
state_dir = "files/build"    # ✓ exists
crash_dir = "files/crash"    # ✓ exists  
log_dir = "files/logs"       # ✗ missing
models_dir = "models"        # ✗ missing
scripts_dir = "scripts"      # ✓ exists
```

**In scripts/setup_llm.sh line 20:**
- References models being checked but no models directory exists

**In DEPLOYMENT.md line 320:**
- "Check model files exist in `models/` directory"

## Missing Directories

1. **files/logs/** - Referenced in config.toml but doesn't exist
2. **models/** - Referenced in multiple places:
   - config.toml line 88
   - scripts/setup_llm.sh checks for models
   - DEPLOYMENT.md line 320
   - AzerothCore setup guide references model downloads

## Impact

- Applications may fail trying to write to missing log directory
- LLM setup will fail when trying to check for models
- User confusion when following deployment guides

## Current Directory Structure

```
files/
├── build/     ✓ exists
└── crash/     ✓ exists

Missing:
├── logs/      ✗ missing  
models/        ✗ missing
```

## Suggested Fixes

1. **Create missing directories:**
   ```bash
   mkdir -p files/logs
   mkdir -p files/ai/models/image
   mkdir -p files/ai/models/llm
   ```

2. **Update build scripts** to create directories automatically

3. **Add .gitkeep files** to maintain empty directories in git

4. **Update documentation** to mention directory creation or make it automatic

5. **Ensure paths are correctly referenced** to make sure the code knows where to look

## Line Numbers

- config.toml: Lines 87-88 (log_dir, models_dir)
- DEPLOYMENT.md: Line 320 (model files reference)
- scripts/setup_llm.sh: References to models

## Priority

Medium - Could cause runtime failures in fresh installations
