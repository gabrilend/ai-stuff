# Enhanced Input System - Quick Reference

## Controller Button Layout

### Game Boy Style
```
    SELECT  START
    ┌─────┐ ┌─────┐
    │  ↑  │ │  A  │
┌───┤  ←  ├─┤     │
│   │  →  │ │  B  │ 
└───┤  ↓  │ └─────┘
    └─────┘
```

### SNES Style  
```
    SELECT  START
    ┌─────┐ ┌─────┐   ┌─────┐
    │  ↑  │ │  Y  │   │  L  │
┌───┤  ←  ├─┤ X A │   └─────┘
│   │  →  │ │  B  │   ┌─────┐
└───┤  ↓  │ └─────┘   │  R  │
    └─────┘           └─────┘
```

## Input Modes

### Navigation Mode (Default)
| Button | Action |
|--------|--------|
| D-pad | Navigate UI elements |
| A | Select/Confirm |
| B | Back/Cancel |
| SELECT | → Enter Edit Mode |
| START | Context menu |

### Edit Mode
| Button | Action |
|--------|--------|
| D-pad | Move cursor |
| A | → Open One-Time Keyboard |
| B | Backspace |
| SELECT | → Exit Edit Mode |
| L/R | Word navigation (optional) |

### One-Time Keyboard (Game Boy)
| Button | Action |
|--------|--------|
| D-pad | Navigate character sectors |
| A | Select character → Exit |
| B | Cancel → Return to Edit Mode |

### Radial Menu (SNES)
| D-pad | Opens | A/Y/B/X/L/R Select |
|-------|-------|-------------------|
| UP | Uppercase (A-F) | Position 1-6 |
| DOWN | Lowercase (a-f) | Position 1-6 |
| LEFT | Numbers (0-5) | Position 1-6 |
| RIGHT | Symbols (!@#) | Position 1-6 |

## Character Sectors (Game Boy)

### Sector Layout
```
┌─────────┬─────────┐
│    UP   │   A-D   │
│ (North) │ a b c d │
├─────────┼─────────┤
│  DOWN   │   E-H   │
│ (South) │ e f g h │
├─────────┼─────────┤
│  LEFT   │   I-L   │
│ (West)  │ i j k l │
├─────────┼─────────┤
│  RIGHT  │   M-P   │
│ (East)  │ m n o p │
└─────────┴─────────┘
```

## Radial Menu Layout (SNES)

### Button Positions
```
        A (12:00)
    L       Y (2:00)
(10:00)   ○   
    X   ● ○   B (4:00)
(8:00)    ○
        R (6:00)
```

### Character Sets
- **UP + A**: First uppercase set (A,B,C,D,E,F)
- **UP + Y**: Second uppercase set (G,H,I,J,K,L)
- **DOWN + A**: First lowercase set (a,b,c,d,e,f)
- **LEFT + A**: Numbers (0,1,2,3,4,5)
- **RIGHT + A**: Symbols (!,@,#,$,%,^)

## Special Actions

### Long Press Actions
| Action | Result |
|--------|--------|
| Long Press A (1s) | Open symbols keyboard |
| Hold L+R | Open emoji keyboard |

### Configuration
```json
{
  "trigger": {"LongPress": {"button": "A", "duration_ms": 1000}},
  "result": {"OpenKeyboard": {"layout": "symbols"}}
}
```

## Mode Transitions

```
Navigation ←→ Edit Mode ←→ One-Time Keyboard
    ↓             ↓
    └─→ Radial Menu (SNES only)
```

### Transition Triggers
- **Navigation → Edit**: SELECT button
- **Edit → Navigation**: SELECT button or timeout (30s)
- **Edit → Keyboard**: A button
- **Keyboard → Edit**: Character selection or B button
- **Edit → Radial**: D-pad (SNES only)

## Quick Tips

### Efficient Text Entry
1. **Game Boy**: Use SELECT → A → navigate → select → repeat
2. **SNES**: Use D-pad directions for character sets, face buttons for selection
3. **Mixed Mode**: Configure both for different text types

### Cursor Navigation
- **Single Character**: D-pad left/right
- **Word Boundaries**: L/R buttons (if configured)
- **Line Navigation**: D-pad up/down

### Battery Saving
- Set shorter auto-exit timeout
- Use slower cursor blink rate
- Enable low-power mode in config

## Common Sequences

### Game Boy Text Entry
```
1. SELECT     (enter edit mode)
2. A          (open keyboard)
3. UP         (navigate to A-D sector)
4. A          (select 'a')
5. A          (open keyboard again)
6. DOWN       (navigate to E-H sector)  
7. B          (select 'f')
8. SELECT     (exit edit mode)
Result: "af"
```

### SNES Text Entry
```
1. SELECT     (enter edit mode)
2. UP         (open uppercase radial)
3. A          (select 'A')
4. DOWN       (open lowercase radial)
5. Y          (select 'b')
6. SELECT     (exit edit mode)
Result: "Ab"
```

## Error Recovery
- **Stuck in mode**: Press SELECT to return to edit mode
- **Wrong character**: Use B to backspace
- **Lost cursor**: D-pad to navigate, position shown in status
- **Config issues**: Reset to default with gameboy_style() or snes_style()

## Performance Tips
- Use SNES mode for faster text entry
- Configure shorter timeouts for battery devices
- Use word navigation (L/R) for long texts
- Set up custom character sets for frequent symbols