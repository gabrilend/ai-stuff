# Issue 007: AI Personality System

## Current Behavior
No AI decision-making system exists.

## Intended Behavior
Implement a 2-axis personality matrix (X/Y values) with 4 personality types (red, blue, green, yellow). Each unit uses their personality to make decisions, with each choice having a percentage chance based on their position in the matrix.

## Suggested Implementation Steps
1. Design 2-axis personality matrix data structure
2. Define the 4 personality types and their characteristics:
   - Red: Aggressive/Direct solutions
   - Blue: Defensive/Cautious solutions  
   - Green: Balanced/Adaptive solutions
   - Yellow: Creative/Unconventional solutions
3. Implement decision-making system with percentage-based choices
4. Create Dijkstra maps for spatial awareness around units
5. Implement conceptual Dijkstra maps informed by personality
6. Add personality-based behavior trees for different situations
7. Create visual indicators for unit personality types
8. Add personality inheritance/modification systems

## Priority
Medium - Important for unit behavior but not blocking core mechanics

## Estimated Effort
3-4 weeks

## Dependencies
- Issue 001 (Project Setup)
- Issue 003 (Basic Unit System)

## Related Documents
- docs/technical-overview.md (lines 90-97: AI personality matrix)
- notes/technical-overview.md

## Technical Notes
- Personality stored as simple X/Y coordinate in 2D space
- Each decision has 4 options with personality-based percentages
- Dijkstra maps provide spatial and conceptual awareness
- Visual feedback helps players understand unit behavior

## Acceptance Criteria
- Units make decisions based on personality matrix
- Behavior feels distinct between personality types
- Dijkstra mapping provides intelligent spatial awareness
- Performance acceptable with multiple AI units
- Visual clarity for player understanding of unit behavior