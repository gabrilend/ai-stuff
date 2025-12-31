# Issue 509: Player-Customizable Visual Effects

**Phase:** 5
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 501 (renderer interface), 503 (sprite system), 508 (vertical slice)

---

## Current Behavior

Visual effects (spells, abilities, auras, projectiles) render with fixed colors and
appearances. All players see identical effect visuals regardless of character
customization. There is no connection between character model features and effect
rendering.

## Intended Behavior

Visual effects adapt their appearance based on the casting character's customization
features. This creates a personalized visual identity where:

1. **Effect colors derive from character appearance:**
   - Hair color influences energy/magic effect tints
   - Skin tone can influence certain nature/earth effects
   - Tattoo colors/patterns can manifest in ability visuals
   - Jewelry colors (gems, metals) tint auras and buffs

2. **Per-player viewport customization:**
   - Players can configure how THEIR effects appear to themselves
   - Players can configure how OTHERS' effects appear in their viewport
   - Optional "authentic mode" shows effects as the caster customized them
   - Colorblind and accessibility modes override with high-contrast palettes

3. **WoW-Chat integration:**
   - Character customization data stored in WoW-Chat profile system
   - Effect preferences synchronized across sessions
   - Social features allow players to "preview" others' effect styles
   - Customization unlocks/achievements track visual personalization

4. **Technical considerations:**
   - Effect color parameters extracted at spawn time
   - Color blending modes: replace, tint, additive, multiply
   - Fallback to default colors if character data unavailable
   - Performance: color lookup cached, not per-frame

## Suggested Implementation Steps

### Sub-Issue 509a: Character Appearance Data Model
1. Define character customization schema (hair_color, skin_tone, tattoo_colors[], jewelry_colors[])
2. Create appearance extraction API for effect systems
3. Store primary/secondary/accent colors derived from appearance
4. Implement color inheritance rules (which features affect which effect types)

### Sub-Issue 509b: Effect Color Parameter System
1. Extend effect spawn data to include color overrides
2. Create color blending mode enum (REPLACE, TINT, ADDITIVE, MULTIPLY)
3. Implement per-effect-type color mapping configuration
4. Add "colorable regions" metadata to effect definitions

### Sub-Issue 509c: Viewport Preference System
1. Create player viewport settings structure
2. Implement "self effects" vs "other effects" preference split
3. Add accessibility override modes (colorblind palettes)
4. Store preferences in player profile (WoW-Chat compatible)

### Sub-Issue 509d: WoW-Chat Profile Integration
1. Define customization data API between engine and WoW-Chat
2. Implement profile sync for effect preferences
3. Add preview capability for viewing others' effect styles
4. Create customization achievement/unlock framework

### Sub-Issue 509e: Render Pipeline Integration
1. Hook effect spawner to query appearance colors
2. Implement color parameter injection in effect renderer
3. Add debug visualization for color regions
4. Performance optimization: cache resolved colors per entity

## Acceptance Criteria

- [ ] Character appearance data model defined with color extraction
- [ ] Effect color parameters support tinting from character data
- [ ] Player viewport shows effects with personalized colors
- [ ] Self vs others effect appearance can be configured independently
- [ ] Colorblind/accessibility modes override with high-contrast colors
- [ ] WoW-Chat profile stores and syncs effect preferences
- [ ] Effect color resolution is cached and performant
- [ ] Default fallback colors work when customization unavailable

## Technical Design Notes

### Color Derivation Hierarchy
```
Character Feature       →  Derived Colors        →  Effect Types
─────────────────────────────────────────────────────────────────
Hair Color              →  Primary magic tint    →  Spells, channeling
Skin Tone               →  Earth/nature base     →  Heals, shields
Tattoo Primary          →  Accent energy         →  Crits, procs
Tattoo Pattern          →  Shape influence       →  Particle shapes
Jewelry Metal           →  Aura rim color        →  Buffs, debuffs
Jewelry Gems            →  Projectile core       →  Missiles, bolts
```

### Viewport Configuration Example
```lua
viewport_preferences = {
    self_effects = {
        mode = "custom",       -- "custom", "authentic", "default"
        color_source = "appearance",  -- derive from my character
        intensity = 1.2,       -- slight boost for visibility
    },
    other_effects = {
        mode = "authentic",    -- show as caster intended
        accessibility = nil,   -- or "deuteranopia", "protanopia", etc.
    },
    friendly_override = nil,   -- optional team color influence
    hostile_override = {
        tint = {1.0, 0.3, 0.3},  -- red tint on enemy effects
    }
}
```

### WoW-Chat Integration Points
```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Character DB   │────▶│  Effect Resolver │────▶│  Render System  │
│  (WoW-Chat)     │     │                  │     │                 │
├─────────────────┤     ├──────────────────┤     ├─────────────────┤
│ hair_color      │     │ extract_colors() │     │ spawn_effect()  │
│ skin_tone       │     │ apply_prefs()    │     │ with colors     │
│ tattoos[]       │     │ cache_lookup()   │     │                 │
│ jewelry[]       │     │                  │     │                 │
│ effect_prefs    │     │                  │     │                 │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## Related Documents

- `issues/500-dual-interface-rendering-considerations.md` - WoW-Chat integration strategy
- `docs/render-architecture.md` - Effect rendering pipeline
- `issues/503-build-sprite-placeholder-system.md` - Visual representation systems
- CRITICAL-PATH.md OQ-003/OQ-004 - API-driven integration decisions

## Notes

This feature embodies the project philosophy of providing visual customization through
community-created content rather than recreating original WC3/WoW aesthetics. Players
bring their own visual identity to the shared game world.

The WoW-Chat platform serves as the customization hub, keeping visual preferences
synchronized and enabling social features around personal expression. This aligns
with the API-driven integration approach decided in OQ-003.

Consider implementing a "spectator mode" where observers can toggle between seeing
effects as intended by casters vs their own accessibility preferences.

---

## Revision History

| Date | Change |
|------|--------|
| 2025-12-31 | Initial creation |
