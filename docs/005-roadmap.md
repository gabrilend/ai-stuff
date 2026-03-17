# 005 - Project Roadmap

## Phase 1: Foundation

Establish the core infrastructure: build system, threadpool, and basic
raylib window.

### Deliverables
- Makefile with proper linking
- Threadpool implementation with task queue
- Empty raylib window that opens and closes cleanly
- Basic project structure

### Success Criteria
- `make` produces working executable
- Threadpool unit test passes
- Window opens at 60fps, responds to close

---

## Phase 2: Static World

Create the pachinko machine structure without moving balls.

### Deliverables
- Peg grid generation and rendering
- Score zone layout and rendering
- World state structure
- Visual pachinko board display

### Success Criteria
- Pegs render in staggered grid pattern
- Score zones visible at bottom
- Clean visual layout

---

## Phase 3: Ball Physics

Implement ball spawning, movement, and collision.

### Deliverables
- Ball state and double-buffering
- Gravity and velocity integration
- Peg collision detection and response
- Boundary collision handling
- Ball launching input

### Success Criteria
- Balls fall under gravity
- Balls bounce off pegs realistically
- Balls bounce off walls
- Space key launches new balls

---

## Phase 4: Parallel Processing

Integrate threadpool with ball physics updates.

### Deliverables
- Task data structures for ball updates
- Parallel ball physics submission
- Buffer swapping synchronization
- Thread-safe ball state management

### Success Criteria
- Multiple balls update in parallel
- No race conditions or visual glitches
- Performance scales with thread count

---

## Phase 5: Scoring and Polish

Complete gameplay loop and visual refinement.

### Deliverables
- Score zone detection and scoring
- Score display and tracking
- Ball deactivation when captured
- Visual polish (colors, effects)
- Performance statistics display

### Success Criteria
- Balls score when landing in zones
- Score accumulates correctly
- Smooth gameplay with 100+ balls
- FPS counter shows stable 60fps

---

## Phase 6: Viewport and Window

Viewport management and window handling.

### Deliverables
- Scrolling viewport with Camera2D
- Dynamic window resize handling
- Scroll limits to keep table visible
- UI repositioning on resize

### Success Criteria
- Smooth scrolling through game world
- Window resizes handled gracefully
- UI elements stay properly positioned

---

## Phase 7: Spawn System and UI

Spawn system improvements and UI polish.

### Deliverables
- Auto-spawn toggle (A key)
- Movable spawn point (mouse/keyboard)
- Improved spawn visual display
- Credit-based spawn buffering
- UI repositioned for better visibility

### Success Criteria
- Consistent spawn rate regardless of input method
- Intuitive spawn point control
- Clear visual feedback for spawn state

---

## Phase 8: Game Mechanics

Upgrade system and adversary opponent.

### Deliverables
- Upgrade menu system (spend points on improvements)
- Spawn rate upgrade
- Ball radius upgrade
- Adversary board (mirrored below player)
- Adversary AI (oscillating reticle, auto-spawn)
- Shared gates (balls pass through to opposite board)
- Cross-board ball physics (reversed gravity, momentum transfer)

### Success Criteria
- Upgrades purchasable and functional
- Enemy board renders correctly (flipped orientation)
- Balls pass through shared gates to opposite board
- Cross-board collisions transfer momentum correctly

---

## Phase 9: Optimization (Future)

Performance improvements for high ball counts.

### Deliverables
- Spatial partitioning for collision
- SIMD physics calculations
- Memory pool for ball allocation

### Success Criteria
- 500+ balls at 60fps
- Reduced collision check overhead
