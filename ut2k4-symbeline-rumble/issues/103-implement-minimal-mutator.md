# Issue 103: Implement Minimal Mutator That Loads Successfully

## Status
- Phase: 1
- Priority: Critical
- Status: Open
- Dependencies: 102-create-mod-package-structure

## Current Behavior
Mutator class exists but may not load properly in-game or may have no functionality.

## Intended Behavior
A minimal mutator that:
- Loads without errors when selected in-game
- Appears in the mutator selection list
- Writes to log confirming it loaded
- Does not interfere with normal gameplay
- Provides foundation for future features

## Suggested Implementation Steps

### 1. Implement Core Mutator Functions

```unrealscript
class SR_SymbelineRumbleMutator extends Mutator;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    Log("SymbelineRumble: Mutator loaded successfully");
}

static function string GetDescriptionstring()
{
    return "Symbeline Rumble - Warcraft Rumble mechanics for UT2004";
}

defaultproperties
{
    GroupName="SymbelineRumble"
    FriendlyName="Symbeline Rumble"
    Description="Total conversion: Warcraft Rumble style gameplay"
}
```

### 2. Add Logging System
- Implement debug logging function
- Log important lifecycle events:
  - PostBeginPlay()
  - Destroyed()
  - Any initialization
- Use meaningful log prefixes for grep-ability

### 3. Create Version Information
- Add version constant to mutator
- Log version on startup
- Include in description string
- Format: v0.1.0-phase1

### 4. Implement Graceful Initialization
- Check for required game types
- Verify map compatibility
- Log warnings for unsupported configurations
- Don't crash, just warn and continue

### 5. Add Configuration Hooks
- Prepare for future config file
- Add placeholder config variables
- Document where config will live
- Don't implement config loading yet (future phase)

### 6. Testing Protocol
- Launch UT2004
- Open mutator selection menu
- Verify mutator appears in list
- Enable mutator
- Start a match
- Check UT2004.log for load confirmation
- Verify game plays normally
- Test on multiple map types:
  - DM map
  - ONS map
  - CTF map (ensure doesn't break other modes)

## Related Documents
- docs/001-architecture-overview.md
- docs/005-roadmap.md (Phase 1)

## Tools Required
- UT2004 installation
- Compiled SymbelineRumble package
- Access to UT2004.log file

## Technical Notes

### Expected Log Output
```
SymbelineRumble: Mutator loaded successfully
SymbelineRumble: Version v0.1.0-phase1
SymbelineRumble: Initialized on map: DM-Rankin
```

### Common Issues
- Mutator doesn't appear in list: Check .int file exists
- Mutator crashes on load: Check for syntax errors, missing dependencies
- Log messages don't appear: Verify Log() calls are correct

### Mutator Lifecycle
1. Class loaded by game
2. Instance created
3. PreBeginPlay() called
4. BeginPlay() called
5. PostBeginPlay() called ← Our initialization goes here
6. Tick() called every frame (if enabled)
7. Destroyed() called on cleanup

## Acceptance Criteria
- [ ] Mutator appears in in-game mutator selection menu
- [ ] Mutator can be enabled without errors
- [ ] Game starts successfully with mutator active
- [ ] Log file shows successful load message
- [ ] Mutator displays correct name and description
- [ ] Game plays normally (no gameplay disruption)
- [ ] Works on DM, ONS, and CTF maps
- [ ] No error messages in log
- [ ] Can complete a full match without crashes

## Notes
This is a proof-of-concept. The mutator should do absolutely nothing except confirm it can load. All gameplay features come in later phases.

Do not be tempted to add features yet. The goal is purely to establish that we can compile, load, and run a mutator in the UT2004 environment.
