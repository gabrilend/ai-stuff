# Dark Volcano - Technical Overview

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
                      glow and the body and background is dark
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
