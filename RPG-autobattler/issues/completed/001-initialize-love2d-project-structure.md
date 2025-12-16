# Issue #001: Initialize Love2D Project Structure

## Current Behavior
No project structure exists for the RPG-autobattler game.

## Intended Behavior
A properly organized Love2D project structure should be created with appropriate directories and basic files to support development.

## Implementation Details

### Required Directory Structure
```
/
├── main.lua                 # Entry point
├── conf.lua                # Love2D configuration
├── src/                    # Source code
│   ├── systems/           # Game systems (combat, movement, etc.)
│   ├── entities/          # Unit, base, projectile classes
│   ├── components/        # ECS components
│   ├── utils/             # Utility functions
│   └── constants/         # Game constants and configuration
├── assets/                # Game assets (if any)
├── tests/                 # Unit tests
└── lib/                   # Third-party libraries
```

### Key Files to Create
1. **main.lua**: Basic Love2D entry point with empty callbacks
2. **conf.lua**: Game configuration (window size, title, etc.)
3. **src/utils/init.lua**: Utility module loader
4. **src/constants/game.lua**: Game constants (colors, sizes, etc.)

### Considerations
- Follow Love2D best practices for project organization
- Ensure modular structure for easy expansion
- Include placeholder files to establish directory structure
- Consider using a consistent require() pattern

### Tool Suggestions
- Use Write tool to create each file
- Use Bash tool to verify directory structure with `tree` or `ls -la`
- Check Love2D documentation for recommended project structure

### Acceptance Criteria
- [ ] All directories created
- [ ] main.lua exists and can be loaded by Love2D
- [ ] conf.lua configures basic game settings
- [ ] Placeholder files exist in key directories
- [ ] Project can be run with `love .` command