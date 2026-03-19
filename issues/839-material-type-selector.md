# 839 - Material Type Selector

## Status: Open

## Parent Phase: See phase progress file

## Problem

Objects with physics properties (restitution, friction) are currently edited via raw RGB values. This is unintuitive for most users who would better understand material types like "rock", "ice", or "bouncy".

## Current Behavior

- Restitution stored in R channel
- Friction stored in G channel (or similar mapping)
- Users edit raw numeric values (0-255)
- No visual indication of what values mean

## Intended Behavior

### Standard Mode (Default)

Material selection via dropdown or icon grid:

```
┌─────────────────────────────────┐
│ Material:                       │
│ ┌─────┬─────┬─────┬─────┬─────┐ │
│ │ 🪨  │ 🧊  │ 🔴  │ 🟤  │ 🟡  │ │
│ │Stone│ Ice │Rubber│Sticky│Bouncy│ │
│ └─────┴─────┴─────┴─────┴─────┘ │
│         [Stone ▼]               │  ← Or dropdown
└─────────────────────────────────┘
```

### Advanced Mode

Direct RGB/property editing for power users:

```
┌─────────────────────────────────┐
│ ☑ Advanced Mode                 │
│                                 │
│ Restitution: [====●===] 180     │
│ Friction:    [==●=====]  50     │
│ (Reserved):  [●=======]   0     │
└─────────────────────────────────┘
```

## Material Definitions

```c
typedef struct Material {
    const char* name;
    const char* icon;           // Unicode or texture path
    const char* description;

    // Physics properties (map to RGB)
    unsigned char restitution;  // R channel
    unsigned char friction;     // G channel
    unsigned char reserved;     // B channel (future use)

    // Visual properties
    Color display_color;        // For editor preview
} Material;

// Predefined materials
static const Material MATERIALS[] = {
    {
        .name = "Stone",
        .icon = "🪨",
        .description = "Standard surface, moderate bounce",
        .restitution = 180,
        .friction = 50,
        .reserved = 0,
        .display_color = { 128, 128, 128, 255 }
    },
    {
        .name = "Ice",
        .icon = "🧊",
        .description = "Slippery, low friction",
        .restitution = 150,
        .friction = 10,
        .reserved = 0,
        .display_color = { 180, 220, 255, 255 }
    },
    {
        .name = "Rubber",
        .icon = "🔴",
        .description = "High bounce, good grip",
        .restitution = 220,
        .friction = 80,
        .reserved = 0,
        .display_color = { 200, 80, 80, 255 }
    },
    {
        .name = "Sticky",
        .icon = "🟤",
        .description = "Absorbs energy, high friction",
        .restitution = 50,
        .friction = 200,
        .reserved = 0,
        .display_color = { 100, 70, 50, 255 }
    },
    {
        .name = "Bouncy",
        .icon = "🟡",
        .description = "Maximum bounce, low friction",
        .restitution = 250,
        .friction = 20,
        .reserved = 0,
        .display_color = { 255, 220, 50, 255 }
    },
    {
        .name = "Glass",
        .icon = "💎",
        .description = "Moderate bounce, very slippery",
        .restitution = 170,
        .friction = 5,
        .reserved = 0,
        .display_color = { 200, 230, 255, 200 }
    },
    {
        .name = "Metal",
        .icon = "⚙️",
        .description = "High bounce, low friction",
        .restitution = 200,
        .friction = 30,
        .reserved = 0,
        .display_color = { 180, 180, 200, 255 }
    },
    {
        .name = "Custom",
        .icon = "⚙️",
        .description = "User-defined values",
        .restitution = 128,
        .friction = 128,
        .reserved = 0,
        .display_color = { 128, 128, 128, 255 }
    },
};

#define MATERIAL_COUNT (sizeof(MATERIALS) / sizeof(MATERIALS[0]))
```

## RGB Mapping

The existing RGB system maps directly to physics:

| Channel | Property | Range | Notes |
|---------|----------|-------|-------|
| R | Restitution | 0-255 | 0=absorb, 255=super bounce |
| G | Friction | 0-255 | 0=ice, 255=velcro |
| B | Reserved | 0-255 | Future: sound, particles, etc. |

Materials simply provide presets for these values. In advanced mode, users edit R/G/B directly.

### Material to RGB Conversion

```c
Color material_to_color(const Material* mat) {
    return (Color){
        mat->restitution,
        mat->friction,
        mat->reserved,
        255  // Alpha always full
    };
}

// Find closest material for given RGB values
int find_closest_material(unsigned char r, unsigned char g, unsigned char b) {
    int best_match = MATERIAL_COUNT - 1;  // Default to "Custom"
    int best_distance = INT_MAX;

    for (int i = 0; i < MATERIAL_COUNT - 1; i++) {  // Skip "Custom"
        int dr = (int)r - MATERIALS[i].restitution;
        int dg = (int)g - MATERIALS[i].friction;
        int db = (int)b - MATERIALS[i].reserved;
        int dist = dr*dr + dg*dg + db*db;

        if (dist == 0) return i;  // Exact match
        if (dist < best_distance) {
            best_distance = dist;
            best_match = i;
        }
    }

    // If no close match, return Custom
    if (best_distance > 100) {  // Threshold
        return MATERIAL_COUNT - 1;
    }
    return best_match;
}
```

## Configuration

### config.txt

```
# Editor settings
EDITOR_ADVANCED_MODE=0    # 0=material presets, 1=raw RGB editing
```

### Command Line Flag

```bash
# Run editor in advanced mode
./bin/board-editor --advanced

# Or short form
./bin/board-editor -a
```

### Runtime Toggle

Advanced mode can also be toggled in the editor:

```c
// In editor state
int advanced_mode = 0;

// Toggle via menu or keybind
if (IsKeyPressed(KEY_F12)) {
    advanced_mode = !advanced_mode;
}
```

## Inspector Panel Integration

### Standard Mode

```c
void inspector_render_material_standard(Panel* panel, int* material_index) {
    panel_add_widget(panel, widget_label("Material"));

    // Icon grid (2 rows x 4 columns)
    for (int i = 0; i < MATERIAL_COUNT; i++) {
        Rectangle btn = calculate_grid_button(i, 4);  // 4 columns

        int is_selected = (i == *material_index);
        Color bg = is_selected ? SKYBLUE : LIGHTGRAY;

        DrawRectangleRec(btn, bg);
        DrawText(MATERIALS[i].icon, btn.x + 8, btn.y + 4, 20, BLACK);

        // Tooltip on hover
        if (CheckCollisionPointRec(GetMousePosition(), btn)) {
            draw_tooltip(MATERIALS[i].name, MATERIALS[i].description);
        }
    }

    // Or as dropdown
    panel_add_widget(panel, widget_dropdown("Material", material_index,
        material_names, MATERIAL_COUNT));
}
```

### Advanced Mode

```c
void inspector_render_material_advanced(Panel* panel,
                                        unsigned char* restitution,
                                        unsigned char* friction,
                                        unsigned char* reserved) {
    panel_add_widget(panel, widget_label("Physics (Advanced)"));

    float rest_f = *restitution;
    float fric_f = *friction;
    float resv_f = *reserved;

    panel_add_widget(panel, widget_slider("Restitution", &rest_f, 0, 255, 1));
    panel_add_widget(panel, widget_slider("Friction", &fric_f, 0, 255, 1));
    panel_add_widget(panel, widget_slider("Reserved", &resv_f, 0, 255, 1));

    *restitution = (unsigned char)rest_f;
    *friction = (unsigned char)fric_f;
    *reserved = (unsigned char)resv_f;

    // Show closest material name
    int closest = find_closest_material(*restitution, *friction, *reserved);
    panel_add_widget(panel, widget_label_formatted("≈ %s", MATERIALS[closest].name));
}
```

## Board JSON Storage

Materials are stored as RGB values for compatibility:

```json
{
  "objects": [
    {
      "type": "line",
      "col": 0, "row": 5,
      "end_col": 3, "end_row": 7,
      "color": [220, 80, 0, 255],
      "thickness": 4
    }
  ]
}
```

When loading, `find_closest_material()` determines which preset to show. Custom values display as "Custom" in standard mode.

## Visual Feedback

Objects should render with their material's display color:

```c
void render_line(Line* line) {
    int mat_idx = find_closest_material(line->restitution, line->friction, 0);
    Color render_color = MATERIALS[mat_idx].display_color;

    DrawLineEx(start, end, line->thickness, render_color);
}
```

This gives visual consistency: all "Ice" lines look icy blue, all "Rubber" lines look red, etc.

## Implementation Steps

1. Define Material struct and predefined materials array
2. Add material_to_color() and find_closest_material() functions
3. Add EDITOR_ADVANCED_MODE to config system
4. Add --advanced / -a command line flag parsing
5. Create material icon grid widget
6. Create material dropdown widget
7. Update inspector to show material selector (standard mode)
8. Update inspector to show sliders (advanced mode)
9. Add F12 keybind to toggle modes at runtime
10. Update object rendering to use material display colors
11. Test material presets match expected physics behavior
12. Add tooltips with material descriptions

## Files to Create

- `src/050-material.h` - Material struct and presets
- `src/050-material.c` - Material lookup functions

## Files to Modify

- `config.txt` - Add EDITOR_ADVANCED_MODE option
- `scripts/generate-config.sh` - Handle new config key
- `src/030-editor-main.c` - Parse --advanced flag
- `src/032-editor-app.c` - Toggle between standard/advanced inspectors
- `src/035-object-render.c` - Use material display colors

## Notes

- Icon grid is more visual but takes more space than dropdown
- Could support both: grid for quick selection, dropdown as alternative
- Consider allowing custom material definitions in a materials.json file
- Sound effects could be tied to materials in the future (B channel)
- Particle effects on collision could vary by material
