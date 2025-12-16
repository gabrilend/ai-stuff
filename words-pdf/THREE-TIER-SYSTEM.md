# Three-Tier Theme System Integration

## Overview

The art-test files have been configured to use the three-tier theme taxonomy system from `theme-analysis/backups/final-theme-taxonomy-3.md`. This system provides a hierarchical approach to generating artwork that matches the complexity and depth of the poetry content.

## Implementation

### New Files Created

1. **`art-test-tiered-themes.lua`** - Main implementation showcasing the full three-tier system
2. **`test-tiered-themes.sh`** - Test runner script for the tiered system
3. **`test-clean-with-poems.sh`** - Test runner for the updated clean version

### Updated Files

1. **`art-test-clean.lua`** - Updated to include tier-1 themes and sample poems

## Three-Tier System Architecture

### Tier 1: Core Themes (Full-Page Background Art)
- **Purpose**: Primary background art that sets the overall visual mood
- **Usage**: Covers the entire page as a base layer
- **Themes**: resistance, technology, isolation, identity, systems, connection, chaos, transcendence, survival, creativity
- **Visual Characteristics**:
  - `resistance`: Bold reds and blacks, sharp angular forms, broken chains
  - `technology`: Electric blues and greens, circuit board layouts, network topologies  
  - `isolation`: Muted grays and blues, sparse compositions, vast negative space
  - `identity`: Prismatic refractions, rainbow spectrums, morphing shapes
  - `systems`: Blueprint blues, network diagrams, hierarchical trees
  - `connection`: Warm oranges and yellows, interconnected webs, flowing connections
  - `chaos`: Glitch aesthetics, RGB separation, broken grids
  - `transcendence`: Deep purples and golds, sacred geometry, mandala forms
  - `survival`: Earth tones, root systems, resource flow networks
  - `creativity`: Artist palette variations, brush strokes, dynamic creative energy

### Tier 2: Extended Themes (Individual Poem Artwork)
- **Purpose**: Specific artwork surrounding individual poems
- **Usage**: Decorative elements around poem boxes
- **Themes**: digital_resistance, neurodivergence, gender_fluidity, digital_loneliness, mutual_aid, economic_anxiety, technomysticism, fragmented_consciousness, gaming_culture, environmental_awareness
- **Implementation Examples**:
  - `digital_resistance`: Encryption patterns, lock symbols
  - `neurodivergence`: Complex geometric patterns representing neural pathways
  - `gender_fluidity`: Flowing, morphing shapes with gradient effects
  - `digital_loneliness`: Network nodes with broken connections

### Tier 3: Detailed Themes (Color Determination)
- **Purpose**: Color palette determination for poem backgrounds and secondary artwork
- **Usage**: Generates specific RGB values for poem background colors
- **Themes**: direct_action, programming_philosophy, autistic_masking, trans_experience, witchcraft_practice, cosmic_consciousness, food_security, artistic_expression, social_media_fatigue, economic_systems
- **Color Examples**:
  - `direct_action`: Revolutionary red (0.8, 0.1, 0.1)
  - `programming_philosophy`: Code blue (0.0, 0.6, 0.8)
  - `autistic_masking`: Soft purple (0.7, 0.7, 0.9)
  - `trans_experience`: Trans pink (0.9, 0.5, 0.8)

## Sample Poems

The system includes 10 creative sample poems (4-6 lines each) that demonstrate how poetry interacts with the different theme layers:

1. \"digital rivers flow through midnight screens...\" (technology/digital themes)
2. \"resistance blooms in encrypted fields...\" (revolutionary themes)
3. \"alone in crowds of glowing faces...\" (isolation themes)
4. \"identity shifts like morning mist...\" (identity themes)
5. \"systems dance in perfect order...\" (systems themes)
6. \"bridges built from hope and wire...\" (connection themes)
7. \"chaos fragments break the screen...\" (chaos themes)
8. \"stardust spirals through the night...\" (transcendence themes)
9. \"roots dig deep for sustenance...\" (survival themes)
10. \"colors burst from brush to canvas...\" (creativity themes)

## Testing and Usage

### Running the Tests

```bash
# Test the full three-tier system
./test-tiered-themes.sh

# Test the updated clean version with poems
./test-clean-with-poems.sh

# Traditional clean test (no library path setup needed)
lua5.2 art-test-clean.lua
```

### Output Files

- `art-test-tiered-output.pdf` - Full three-tier system demonstration (10 pages)
- `art-test-output.pdf` - Updated clean version with poems (11 pages)

## Integration with Main System

The tiered theme system is designed to integrate with the main `compile-pdf.lua` by:

1. **Background Analysis**: Analyzing full page content to determine Tier 1 theme
2. **Individual Poem Analysis**: Analyzing each poem to determine Tier 2 theme for surrounding artwork
3. **Color Generation**: Using Tier 3 themes to generate appropriate background colors for each poem
4. **Layered Rendering**: Drawing art in proper order (Tier 1 background → Tier 2 poem art → Tier 3 colors → text)

## Theme Taxonomy Mapping

The system faithfully implements the taxonomy from `final-theme-taxonomy-3.md`:

- **40 total themes** across three hierarchical tiers
- **Complete keyword mapping** for theme detection
- **Visual style specifications** for each theme category
- **Prevalence weighting** to guide theme selection algorithms

This creates a rich, contextually-aware art generation system that responds intelligently to the content and themes present in the poetry while maintaining visual coherence across the document.