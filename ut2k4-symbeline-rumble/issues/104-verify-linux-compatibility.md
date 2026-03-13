# Issue 104: Verify Compatibility With Base UT2004 Linux Version

## Status
- Phase: 1
- Priority: High
- Status: Open
- Dependencies: 103-implement-minimal-mutator

## Current Behavior
Unknown if mutator works on base UT2004 Linux version without patches.

## Intended Behavior
Confirmed compatibility with the base UT2004 Linux release (version 3369.2 or similar base version). The mutator should:
- Compile with base UnrealScript compiler
- Load without requiring patched features
- Run without relying on later-added functionality
- Work on base maps and game modes

## Suggested Implementation Steps

### 1. Identify Target UT2004 Version
- Document exact Linux version being targeted
- Record build number
- Note any patches applied (or not applied)
- Create baseline version documentation

### 2. Audit Code for Version-Specific Features
- Review all UnrealScript code
- Check for classes/functions added in patches
- Verify all base classes exist in target version
- Document any compatibility concerns

### 3. Create Compatibility Test Checklist
Test mutator on base Linux version with:
- [ ] DM-Rankin (standard DM map)
- [ ] ONS-Torlan (standard ONS map)
- [ ] CTF-FaceClassic (standard CTF map)
- [ ] With bots (various skill levels)
- [ ] Multiplayer (if possible)
- [ ] Different game lengths
- [ ] Different frag/score limits

### 4. Test on Clean Installation
If possible:
- Install UT2004 Linux from original media
- Do not apply patches
- Test mutator compilation
- Test mutator loading and running
- Document any issues

### 5. Document Version Requirements
Create compatibility document:
- Minimum UT2004 version
- Tested versions
- Known incompatibilities
- Workarounds for version differences

### 6. Create Version Check Code
Add to mutator:
```unrealscript
function bool CheckVersion()
{
    local int EngineVersion;

    EngineVersion = Level.EngineVersion;
    Log("SymbelineRumble: Engine version:" @ EngineVersion);

    if (EngineVersion < 3369)
    {
        Log("SymbelineRumble: WARNING - Untested on this engine version");
        return false;
    }

    return true;
}
```

### 7. Test Compiler Compatibility
- Ensure code compiles with base ucc
- Check for syntax that may be version-specific
- Test on oldest reasonable UT2004 Linux version
- Document any compiler quirks

## Related Documents
- docs/001-architecture-overview.md (see Compatibility Requirements section)
- docs/005-roadmap.md (Phase 1)

## Tools Required
- Base UT2004 Linux installation (unpatched or minimally patched)
- Multiple test machines if possible
- Version documentation

## Technical Notes

### UT2004 Linux Base Version
The original Linux release was build 3369.2. This should be the primary target.

### Common Version Issues
- Classes added in patches (rare in UT2004)
- Function signatures changed
- Default property behavior
- Replication differences (for multiplayer)

### Fallback Strategy
If a feature absolutely requires a patch:
1. Document the requirement clearly
2. Implement version check
3. Provide graceful degradation
4. Log warning to user

## Acceptance Criteria
- [ ] UT2004 base version documented
- [ ] Code compiles on base version
- [ ] Mutator loads on base version
- [ ] All test maps work correctly
- [ ] Version check code implemented
- [ ] Compatibility documentation written
- [ ] No errors or crashes on base version
- [ ] Any version requirements clearly documented

## Notes
Per the vision document: "The Linux version is considered the canonical implementation, and all development should target it first."

This means we prioritize Linux compatibility over features. If something doesn't work on Linux base version, we either fix it to work or we don't include it.

## Future Considerations
In later phases, we may create a separate "enhanced" version for newer UT2004 builds, but it must maintain feature parity with the base Linux version. The enhanced version would only add visual polish or optimizations, not core features.
