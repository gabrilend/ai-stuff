# Issue 002: Interactive Input Interface

## Current Behavior
The system only supports command-line execution without any interactive interface for navigation or text selection.

## Intended Behavior
Create a custom non-terminal interface with:
- Console input area at the bottom
- Cursor navigation with arrow keys and vim keybindings
- Combined typing and selection functionality
- Mouse wheel scrolling between words (not cursor positions)
- Left/right click for cursor movement with configurable speed (1.5-3 seconds to screen edge)
- Keyboard tap vs scroll mode with 0.1 second hesitation

## Suggested Implementation Steps
1. Design UI layout with console area and main content display
2. Implement keyboard event handling (arrow keys, vim bindings, tap/scroll modes)
3. Add mouse event handling (wheel scrolling, left/right click movement)
4. Create configurable timing system for cursor movement speeds
5. Implement mode switching between typing and navigation
6. Add user preference settings and configuration storage

## Related Documents
- Source: next-1 file (lines 11-30)
- Related to: Issue 001 (embedding navigation system)

## Metadata
- Priority: High
- Complexity: Advanced
- Dependencies: GUI framework or custom interface library
- Estimated Effort: Large

## Implementation Notes
This may require moving beyond pure Lua to a framework that supports advanced UI interactions. Consider integration with the existing PDF generation pipeline.