# Issue 012 - Implement Character Traits, Emotions, and Opinions System

## Current Behavior
The character system in `src/unit.h` has placeholder structures for advanced character personality features:
```c
typedef struct Traits {
    int placeholder; // TODO: Define trait system
} Traits;

typedef struct Emotions {
    int placeholder; // TODO: Define emotion system  
} Emotions;

typedef struct Opinions {
    int placeholder; // TODO: Define opinion system
} Opinions;
```
These are included in the Unit structure but completely unimplemented, providing no functionality.

## Intended Behavior
Implement comprehensive character personality and psychological systems that enable:
- Rich character traits affecting abilities and behavior
- Dynamic emotional states that change based on events
- Opinion systems for inter-character relationships
- Personality-driven content generation via Lua scripts
- Character development and growth over time
- Integration with adventure systems for narrative depth

## Suggested Implementation Steps

### Phase 3A: Trait System Design and Implementation
1. **Design Trait System Architecture**
   - Research D&D 5e personality traits, ideals, bonds, flaws
   - Design trait categories: Personality, Physical, Mental, Social, Cultural
   - Create trait value system (scales vs. binary vs. weighted)
   - Define trait inheritance and modification rules

2. **Implement Trait Data Structures**
   ```c
   typedef struct Trait {
       char* name;              // "Brave", "Curious", "Stubborn" 
       char* description;       // Full text description
       int category;           // PERSONALITY, PHYSICAL, etc.
       int strength;           // 1-10 trait strength
       float modifier;         // Effect on stats/rolls
       bool is_positive;       // Beneficial vs. detrimental
       char** triggers;        // Situations where trait activates
       int trigger_count;
   } Trait;
   
   typedef struct Traits {
       Trait** trait_list;     // Dynamic array of traits
       int trait_count;
       int max_traits;         // Capacity limit
       float personality_matrix[10][10]; // Trait interactions
   } Traits;
   ```

3. **Create Trait Generation System**
   - Implement random trait generation with cultural/class influences
   - Add trait probability tables based on character background
   - Create trait synergy and conflict detection
   - Add trait point-buy system for player customization

### Phase 3B: Emotion System Implementation  
4. **Design Emotion System**
   - Research psychological emotion models (Big 5, PAD, etc.)
   - Implement base emotions: Joy, Anger, Fear, Sadness, Surprise, Disgust
   - Add compound emotions: Pride, Shame, Hope, Despair
   - Create emotion intensity scaling and decay rates

5. **Implement Emotion Data Structures**
   ```c
   typedef struct Emotion {
       int type;               // EMOTION_JOY, EMOTION_ANGER, etc.
       float intensity;        // 0.0 - 1.0 current strength
       float baseline;         // Character's natural tendency
       int duration;           // How long emotion lasts
       char* trigger_event;    // What caused this emotion
       time_t onset_time;      // When emotion started
   } Emotion;
   
   typedef struct Emotions {
       Emotion current_emotions[12]; // Active emotional state
       float mood_history[24];       // 24-hour emotional history
       float emotional_stability;    // Resistance to mood swings
       int dominant_emotion;         // Currently strongest emotion
       float stress_level;           // Overall stress (0-1)
   } Emotions;
   ```

6. **Create Emotion Processing Engine**
   - Implement emotion trigger system based on events
   - Add emotion interaction rules (fear + anger = rage)
   - Create emotion decay and recovery mechanics
   - Add trait-emotion interactions (brave reduces fear)

### Phase 3C: Opinion and Relationship System
7. **Design Opinion System Architecture**
   - Create opinion categories: Respect, Trust, Affection, Fear, Contempt
   - Implement opinion formation based on character interactions
   - Add cultural and trait-based opinion modifiers
   - Design opinion change mechanics over time

8. **Implement Opinion Data Structures**
   ```c
   typedef struct Opinion {
       char* target_id;        // ID of character this opinion is about
       char* target_name;      // Name for display
       float respect;          // -1.0 to 1.0
       float trust;           // -1.0 to 1.0  
       float affection;       // -1.0 to 1.0
       float fear;            // 0.0 to 1.0
       int relationship_type; // FRIEND, ENEMY, NEUTRAL, FAMILY, etc.
       char** interaction_history; // Record of past interactions
       int history_count;
       time_t last_interaction;
   } Opinion;
   
   typedef struct Opinions {
       Opinion** opinion_list;     // Dynamic array of opinions
       int opinion_count;
       float default_trust;        // How trusting character is generally
       float social_confidence;    // How easily forms relationships
       int charisma_modifier;      // Bonus/penalty to opinion changes
   } Opinions;
   ```

### Phase 3D: Integration and Behavior Systems
9. **Create Personality Behavior Engine**
   - Implement trait-driven decision making algorithms
   - Add emotion-influenced action selection
   - Create opinion-based interaction modifiers
   - Integrate with existing stat system for mechanical effects

10. **Add Lua Scripting Integration**
    - Create Lua functions for personality data access
    - Implement personality-driven content generation
    - Add emotion-based adventure branch triggers
    - Create opinion-influenced dialogue generation

11. **Implement Character Development System**
    - Add trait gain/loss based on experiences
    - Implement emotional growth and adaptation
    - Create opinion change mechanics based on actions
    - Add personality stability vs. growth balance

### Phase 3E: User Interface and Display
12. **Create Personality Display Systems**
    - Add trait display to character sheet UI
    - Create emotion indicators and mood displays  
    - Implement relationship network visualization
    - Add personality summary generation for descriptions

## Dependencies
- Enhanced character generation system
- Integration with Lua scripting (Issue 010)
- Event system for emotion/opinion triggers
- JSON serialization for data persistence
- UI framework for personality display

## Verification Criteria
- Characters generated with consistent, believable personalities
- Emotions change appropriately based on events
- Opinions form and evolve through interactions
- Personality affects character behavior and decision-making
- Lua scripts can access and modify personality data
- Character development occurs over time
- UI displays personality information clearly

## Estimated Complexity
**High** - This is a complex system involving:
- Psychology and personality modeling
- Dynamic data structures and memory management
- Complex interaction algorithms
- Integration with multiple existing systems
- User interface and display components

## Related Issues
- Issue 010: Lua integration (enables personality scripting)
- Issue 008: Progress-ii integration (cross-project character development)
- Future: AI-powered personality generation
- Future: Advanced NPC personality systems
- Future: Personality-driven quest generation

## Notes
This system forms the foundation for advanced RPG character depth. Start with simple implementations and expand complexity gradually. Consider psychological research for realistic personality modeling. Integration with adventure systems will require careful design to avoid overwhelming players with complexity.