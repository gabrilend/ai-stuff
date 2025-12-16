# Dark Volcano - Technical Overview

## Comprehensive Technical Vision
Dark Volcano represents a convergence of cutting-edge technologies and innovative design philosophies that push the boundaries of what's possible in real-time strategy gaming. The technical architecture abandons many conventional game development assumptions in favor of approaches that leverage modern hardware capabilities to their fullest potential. Rather than following established patterns of CPU-centric game logic with GPU-assisted rendering, this system inverts the traditional relationship, making the GPU the primary computational engine while distributing rendering tasks across CPU cores in parallel. This fundamental shift enables unprecedented performance scaling, visual fidelity, and gameplay complexity that would be impossible with conventional architectures.

The integration between systems represents perhaps the most sophisticated aspect of this technical approach. The GPU-calculated game state feeds directly into the procedural animation system, where constraint-based physics simulations create dynamic character movements that respond immediately to changing battlefield conditions. Meanwhile, the AI personality systems influence both unit behavior and procedural animation parameters, creating emergent interactions where a Red-personality unit's aggressive tendencies manifest not just in tactical decisions but in more forceful, dynamic movement animations. The networking layer synchronizes all these systems across multiple clients through deterministic bytecode execution, ensuring that complex emergent behaviors remain consistent across all participants in multiplayer sessions.

The technical challenges solved by this architecture extend far beyond performance optimization. By treating the entire game state as a parallel computation problem solvable on GPU hardware, the system achieves frame-perfect determinism that's essential for competitive multiplayer gaming while simultaneously enabling advanced features like predictive simulation and rollback networking. The procedural animation system eliminates gigabytes of animation data while producing more contextually appropriate character movements than traditional keyframe approaches. The AI-generated music system creates unique audio experiences for every play session while maintaining thematic coherence. Together, these technologies create a game that not only runs better than conventional approaches but provides fundamentally different and superior player experiences.

## Architecture Requirements

### Core Systems
1. **Party Management System**
   - 3x3 grid interface for tactical unit placement (up to 9 units)
   - Real-time party composition and synergy calculation
   - Circle vs Box formation system:
     - Circle: 7 units with persistent aura affecting all
     - Box: Up to 9 units, optional center aura unit affecting 5 positions
   - Unit class system based on FFTA jobs

2. **Strategic Map Engine**
   - Zoomable multi-scale map rendering
     -- as described in the vision document. similar to Sins of a Solar Empire.
   - Location-based building system
     -- as described in the vision document.
   - Terrain generation and randomization
     -- pretty much a flat map with locations generated according to the results
        of random dicerolls which prescribe the available buildings at that
        location that the player can invest in. their castle and the surroundings
        can have any buildings that are typical to their kingdom.

3. **Combat System**
   - Physics-based weapon mechanics (ricochet, explosion)
     -- mostly just for animations. the combat is calculated by applying the
        units damage values as a rate which slowly ticks down the enemy's health
        in a very discrete way. But optimized to display to the user as ticks
        taken off of the healthbar with each swing. The final swing before a
        unit perishes will settle the difference between the linear gradient
        healthbar (hidden) and the chunk-based 4 quarters to a heart style
        healthbar (shown)
   - Particle effects for laser weapons
     -- pretty!
   - Collision detection and response
     -- primarily for animation purposes.

4. **Economy and Production**
   - Resource flow simulation
     -- as described in the vision document.
   - Building input/output processing
     -- as described in the vision document.
   - Item distribution algorithms
     -- as described in the vision document.

5. **Item Management**
   - Gravity simulation for dropped items
     -- very basic gravity, it's simply a timer that ticks down until the unit
        despawns from the world.
   - Inventory and equipment systems
     -- as described in the vision document.
   - Magic item identification mechanics
     -- as described in the vision document.

### Visual Style
- **Tron Aesthetic**: Neon outlines, grid patterns, electronic effects
                      -- the screen is split into a number of segments that
                         matches the number of CPU cores and each one will
                         render the things in that patch of screen. The
                         gamestate will be calculated using basic arithmetic
                         applied to each location on the map according to
                         various filters that are iterated through. The
                         gamestate is calculated on the graphics card.
- **3D Environment**: Support for zoom levels from tactical to strategic
- **Particle Systems**: Laser effects, explosions, item reformation
                        -- primarily visual, to keep the multiplayer packet rate
                           low if possible

### Audio Requirements
- **Electric Submarine Theme**: Electronic/submarine-inspired soundtrack
- **Dynamic Music**: Adaptive music based on game state
                     -- instead of sound effects, we have inputs to the prompt
                        for the auto-generated music AI. Meaning... in the
                        flopsopoly of verbrases, AKA input prompt, add in the
                        relevant words each time they occur and slowly prune
                        the oldest by scaling down their magnitude (repetition
                        count) for they are evanescent.
- **SFX**: Laser weapons, explosions, mechanical sounds
           -- converted to text

### Technology Stack Considerations
- **Game Engine**: Unity or Unreal Engine for 3D capabilities
                   -- prototype made in Raylib with basic triangle-and-quad
                      models with edges drawn in vibrant bright colors and
                      glow and the body and background is dark. the triangle-
                      -and-quad models are animated according to calculations
                      done in vulkan on the graphics card. These animations are
                      not predefined, but rather a miniature optimization
                      problem using the hinges and joints and stabilizing
                      inertias of their constituent host.
- **Networking**: Multiplayer support for party battles
                  -- packets are sent TCP style. They are a stream of udp
                     packets which are assumed to be received, but if no
                     confirmation packet is received they will be sent again
                     after a short period when it's next time to cycle through
                     the list of "unconfirmed packets sent" list. they contain
                     bytecode which is used to recreate the same simulation on
                     each client-side server. the only thing that is sent until
                     received is the changes that are made to the simulation by
                     the player.
- **Physics**: Custom physics for item gravity and weapon mechanics
               -- physics are locations and momentums, and the location is
                  prioritized.
- **AI**: Unit behavior and strategic decision-making
          -- make a dijkstra map of surroundings oriented around the unit, and
             also a conceptual one which is informed by their personality.
             personality is stored as a x/y value in a 2 axis matrix. this
             matrix has 4 types, red blue green and yellow. each is associated
             with different solutions to problems, and every choice has one
             that the unit chooses X/Y% of the time.
