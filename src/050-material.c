// src/050-material.c
// Material system implementation
// Provides predefined physics presets and lookup functions

#include "050-material.h"
#include <limits.h>

// =============================================================================
// Predefined Materials
// =============================================================================

// Issue 839: PhysMaterial presets provide intuitive physics property selection
// Restitution: 0=dead (absorbs all energy), 255=super bounce
// Friction: 0=ice (no grip), 255=sticky (maximum grip)
// Reserved: unused, kept at 0 for future expansion

// {{{ PHYS_MATERIALS array
const PhysMaterial PHYS_MATERIALS[MATERIAL_COUNT] = {
    // Stone: Standard surface, moderate bounce and friction
    // Good default for most surfaces
    {
        .name = "Stone",
        .description = "Standard surface, moderate bounce",
        .restitution = 180,
        .friction = 50,
        .reserved = 0,
        .display_color = { 128, 128, 128, 255 }  // Gray
    },

    // Ice: Slippery surface, low friction allows balls to slide
    // Lower bounce to feel more "cold" and inert
    {
        .name = "Ice",
        .description = "Slippery, low friction",
        .restitution = 150,
        .friction = 10,
        .reserved = 0,
        .display_color = { 180, 220, 255, 255 }  // Light blue
    },

    // Rubber: High bounce with good grip
    // Classic bumper material
    {
        .name = "Rubber",
        .description = "High bounce, good grip",
        .restitution = 220,
        .friction = 80,
        .reserved = 0,
        .display_color = { 200, 80, 80, 255 }  // Red
    },

    // Sticky: Absorbs energy, high friction
    // Slows balls down significantly
    {
        .name = "Sticky",
        .description = "Absorbs energy, high friction",
        .restitution = 50,
        .friction = 200,
        .reserved = 0,
        .display_color = { 100, 70, 50, 255 }  // Brown
    },

    // Bouncy: Maximum bounce, low friction
    // Super-charged trampolines
    {
        .name = "Bouncy",
        .description = "Maximum bounce, low friction",
        .restitution = 250,
        .friction = 20,
        .reserved = 0,
        .display_color = { 255, 220, 50, 255 }  // Yellow
    },

    // Glass: Moderate bounce, very slippery
    // Sleek appearance, balls glide along surface
    {
        .name = "Glass",
        .description = "Moderate bounce, very slippery",
        .restitution = 170,
        .friction = 5,
        .reserved = 0,
        .display_color = { 200, 230, 255, 200 }  // Light cyan, slightly transparent
    },

    // Metal: High bounce, low friction
    // Industrial look, good energy transfer
    {
        .name = "Metal",
        .description = "High bounce, low friction",
        .restitution = 200,
        .friction = 30,
        .reserved = 0,
        .display_color = { 180, 180, 200, 255 }  // Silver
    },

    // Custom: User-defined values
    // Shown when RGB doesn't match any preset
    // Default values are neutral midpoint
    {
        .name = "Custom",
        .description = "User-defined values",
        .restitution = 128,
        .friction = 128,
        .reserved = 0,
        .display_color = { 128, 128, 128, 255 }  // Gray (same as Stone)
    }
};
// }}}

// =============================================================================
// Lookup Functions
// =============================================================================

// {{{ phys_material_to_color
Color phys_material_to_color(const PhysMaterial* mat) {
    if (!mat) {
        return (Color){ 128, 128, 0, 255 };
    }
    return (Color){
        mat->restitution,
        mat->friction,
        mat->reserved,
        255
    };
}
// }}}

// {{{ find_closest_material
int find_closest_material(unsigned char restitution, unsigned char friction,
                          unsigned char reserved) {
    int best_match = MATERIAL_COUNT - 1;  // Default to "Custom"
    int best_distance = INT_MAX;

    // Search through all materials except Custom (last one)
    for (int i = 0; i < MATERIAL_COUNT - 1; i++) {
        int dr = (int)restitution - (int)PHYS_MATERIALS[i].restitution;
        int dg = (int)friction - (int)PHYS_MATERIALS[i].friction;
        int db = (int)reserved - (int)PHYS_MATERIALS[i].reserved;
        int dist = dr * dr + dg * dg + db * db;

        if (dist == 0) {
            return i;  // Exact match found
        }

        if (dist < best_distance) {
            best_distance = dist;
            best_match = i;
        }
    }

    // Threshold for considering it a close match
    // If the RGB values are too far from any preset, return Custom
    // Threshold of 100 = ~10 units difference in each channel on average
    if (best_distance > 100) {
        return MATERIAL_COUNT - 1;  // Custom
    }

    return best_match;
}
// }}}

// {{{ material_get_name
const char* material_get_name(int index) {
    if (index < 0 || index >= MATERIAL_COUNT) {
        return "Unknown";
    }
    return PHYS_MATERIALS[index].name;
}
// }}}

// {{{ material_get_description
const char* material_get_description(int index) {
    if (index < 0 || index >= MATERIAL_COUNT) {
        return "";
    }
    return PHYS_MATERIALS[index].description;
}
// }}}

// {{{ material_get_display_color
Color material_get_display_color(int index) {
    if (index < 0 || index >= MATERIAL_COUNT) {
        return (Color){ 128, 128, 128, 255 };  // Default gray
    }
    return PHYS_MATERIALS[index].display_color;
}
// }}}

// {{{ material_apply_to_object
void material_apply_to_object(int index, unsigned char* restitution,
                              unsigned char* friction, unsigned char* reserved) {
    if (index < 0 || index >= MATERIAL_COUNT) {
        return;
    }

    if (restitution) {
        *restitution = PHYS_MATERIALS[index].restitution;
    }
    if (friction) {
        *friction = PHYS_MATERIALS[index].friction;
    }
    if (reserved) {
        *reserved = PHYS_MATERIALS[index].reserved;
    }
}
// }}}
