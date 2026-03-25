// src/050-material.h
// Physics material system for physics properties with user-friendly presets
// Maps RGB property values to named materials with intuitive physics behavior
// Note: Named PhysMaterial to avoid conflict with raylib's Material struct
//
// External functions: phys_material_to_color, find_closest_material, material_get_name,
//                     material_get_description, material_get_display_color

#ifndef PHYS_MATERIAL_H
#define PHYS_MATERIAL_H

#include "raylib.h"

// =============================================================================
// Material Count
// =============================================================================

#define MATERIAL_COUNT 8

// =============================================================================
// Material Structure
// =============================================================================

// {{{ typedef struct PhysMaterial
// PhysMaterial defines a named preset with physics and visual properties.
// Physics properties map to RGB channels for storage compatibility.
// Named PhysMaterial to avoid conflict with raylib's Material struct (issue 839).
typedef struct PhysMaterial {
    const char* name;           // Display name (e.g., "Stone")
    const char* description;    // Tooltip description

    // Physics properties (map to RGB channels)
    unsigned char restitution;  // R channel: bounciness (0=dead, 255=super bounce)
    unsigned char friction;     // G channel: surface grip (0=ice, 255=sticky)
    unsigned char reserved;     // B channel: reserved for future use

    // Visual properties
    Color display_color;        // Color used for editor preview rendering
} PhysMaterial;
// }}}

// =============================================================================
// Predefined Materials Array
// =============================================================================

// Issue 839: PhysMaterial presets provide intuitive physics property selection
// These map to RGB values for storage compatibility with existing board format
extern const PhysMaterial PHYS_MATERIALS[MATERIAL_COUNT];

// =============================================================================
// Material Lookup Functions
// =============================================================================

// {{{ phys_material_to_color
// Converts a physics material to its physics color (restitution, friction, reserved, 255).
// This color is used for storage in board JSON files.
// Parameters:
//   mat: PhysMaterial to convert
// Returns: Color with R=restitution, G=friction, B=reserved, A=255
Color phys_material_to_color(const PhysMaterial* mat);
// }}}

// {{{ find_closest_material
// Finds the material index that best matches the given RGB values.
// Returns MATERIAL_COUNT-1 (Custom) if no close match found.
// Parameters:
//   restitution: R channel value (0-255)
//   friction: G channel value (0-255)
//   reserved: B channel value (0-255)
// Returns: Index into MATERIALS array (0 to MATERIAL_COUNT-1)
int find_closest_material(unsigned char restitution, unsigned char friction,
                          unsigned char reserved);
// }}}

// {{{ material_get_name
// Gets the name of a material by index.
// Parameters:
//   index: Material index (0 to MATERIAL_COUNT-1)
// Returns: Material name string, or "Unknown" if index invalid
const char* material_get_name(int index);
// }}}

// {{{ material_get_description
// Gets the description of a material by index.
// Parameters:
//   index: Material index (0 to MATERIAL_COUNT-1)
// Returns: Material description string, or "" if index invalid
const char* material_get_description(int index);
// }}}

// {{{ material_get_display_color
// Gets the display color of a material by index.
// Parameters:
//   index: Material index (0 to MATERIAL_COUNT-1)
// Returns: Display color, or gray if index invalid
Color material_get_display_color(int index);
// }}}

// {{{ material_apply_to_object
// Applies a material's physics properties to an object's RGB channels.
// Parameters:
//   index: Material index (0 to MATERIAL_COUNT-1)
//   restitution: Pointer to restitution value to set
//   friction: Pointer to friction value to set
//   reserved: Pointer to reserved value to set (or NULL to skip)
void material_apply_to_object(int index, unsigned char* restitution,
                              unsigned char* friction, unsigned char* reserved);
// }}}

#endif // PHYS_MATERIAL_H
