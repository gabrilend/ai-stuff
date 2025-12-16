# Visual Design

## Design Philosophy

### Minimalist Approach
- Intentionally basic visuals using graphics primitives
- Focus on gameplay mechanics over visual complexity
- Clean, readable interface that doesn't distract from strategy

### Technical Implementation
- Built using love2d framework graphics primitives
- Shapes and lines as primary visual elements
- No complex sprites or detailed artwork required

## Color Scheme

### Primary Palette
- **Background**: Pure black (#000000)
- **Primary Colors**: Red, blue, yellow, green for different elements
- High contrast ensures visibility and readability

### Accessibility Design
- **Shape-based Identification**: Primary method for distinguishing elements
- **Color as Enhancement**: Colors provide aesthetic value but aren't required for gameplay
- **Colorblind-Friendly**: All game elements distinguishable by shape alone
- Ensures inclusive design for players with color vision deficiencies

## Visual Elements

### Units
- Represented by distinct geometric shapes
- Different shapes for different unit types/classes
- Shape variations indicate unit roles (melee vs ranged)
- Color coding for team identification (secondary to shape)

### Map Elements
- **Pathways**: Simple line-based representation
- **Bases**: Geometric shapes with clear defensive indicators
- **Lane Boundaries**: Clean lines defining movement areas
- **Sub-paths**: Subtle indicators for formation positioning

### UI Elements
- **Mana Bars**: Simple rectangular progress indicators
- **Health Bars**: Minimalist health representation
- **Resource Display**: Clean numerical or bar-based gold counter
- **Selection Indicators**: Simple outline or highlighting

## Implementation Guidelines

### Rendering Priorities
1. Clarity and readability above all else
2. Consistent visual language throughout
3. Performance optimization through simple shapes
4. Scalable design that works at different resolutions

### Visual Hierarchy
- Important elements (units, bases) use larger shapes
- Secondary elements (UI, effects) use smaller, subtle indicators
- Clear distinction between interactive and decorative elements
- Consistent sizing and spacing throughout interface

## Benefits of Simple Design

### Performance
- Minimal rendering overhead
- Smooth gameplay on lower-end hardware
- Fast development iteration

### Clarity
- No visual clutter to distract from strategy
- Clear identification of all game elements
- Easy to understand at a glance

### Accessibility
- Works for all vision types
- High contrast ensures visibility
- Shape-based design is universally readable