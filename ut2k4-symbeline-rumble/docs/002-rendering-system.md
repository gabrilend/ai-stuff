# Dynamic Occlusion Rendering System

## Purpose

Allow UT2004 maps (default or user-made) to be playable from a top-down perspective by dynamically hiding geometry that would obstruct the player's view of their units.

## MVP Scope

Focus on AI waypoint occlusion detection. Player-based detection is deferred to post-MVP.

## Raycasting Algorithm

### Detection Method
1. Cast rays from each AI waypoint position toward the camera
2. Use a cone-based detection volume to identify all potential occluders
3. Detect both static map geometry and dynamic doodads within the cone
4. Mark detected geometry for rendering modification

### Performance Considerations
- Must update dynamically as camera moves
- Per-player occlusion sets required (different camera positions)
- Optimization: Cache results when camera position hasn't changed significantly

## Rendering Modifications

When geometry is detected as occluding:
- Option A: Make geometry semi-transparent
- Option B: Completely hide the geometry
- Option C: Use wireframe rendering
- Option D: Apply special shader/material

Implementation decision deferred to development phase.

## Multi-Player Handling

Each player with a top-down view requires their own occlusion calculation set because:
- Different camera positions yield different occlusion geometry
- Cannot share occlusion data between players
- Must be efficient enough to handle multiple simultaneous calculations

## Future Enhancements

### Ground-Level Player Detection
When human players are on the ground (not in skybox view):
- Detect occlusion from their position as well
- Combine with AI waypoint detection
- Ensure visibility of nearby ground-level action

### Optimization Strategies
- Spatial partitioning for quick geometry queries
- Level-of-detail for distant occlusion checks
- Update rate scaling based on camera movement speed
