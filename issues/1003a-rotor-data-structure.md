# 1305a - Rotor Data Structure and Storage

## Status: Open

## Parent Issue: 1305 - Rotor System

## Problem

Need a data structure to represent rotors and their connected geometry, plus JSON serialization for board files.

## Implementation

### Data Structures

```c
typedef struct RotorConnection {
    int object_index;           // Index into board objects array
    float relative_angle;       // Angle from rotor center (radians)
    float relative_distance;    // Distance from rotor center
} RotorConnection;

typedef struct Rotor {
    int col, row;               // Grid position of rotor center
    float rotation_speed;       // Radians per second (negative = CCW)
    float current_angle;        // Current rotation state

    RotorConnection* connections;  // Connected objects
    int connection_count;
    int connection_capacity;
} Rotor;

// Add to BoardData
typedef struct BoardData {
    // ... existing fields ...
    Rotor* rotors;
    int rotor_count;
    int rotor_capacity;
} BoardData;
```

### JSON Format

```json
{
  "rotors": [
    {
      "col": 5,
      "row": 10,
      "speed": 1.5,
      "direction": "cw",
      "connections": [3, 7, 12]
    }
  ]
}
```

## Implementation Steps

1. Define Rotor and RotorConnection structs
2. Add rotor array to BoardData
3. Implement rotor creation/destruction functions
4. Add JSON load/save for rotors
5. Implement connection detection algorithm (trace from rotor to find connected objects)

## Files to Modify

- `src/020-board-data.h` - Add rotor structs
- `src/021-board-data.c` - JSON serialization, connection detection

## Notes

- Connection detection should happen when rotor is created and when connected objects change
- Store object indices, not pointers, for serialization
- Relative positions computed from current object positions at creation time
