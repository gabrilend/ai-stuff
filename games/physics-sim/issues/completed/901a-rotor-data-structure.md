# 901a - Rotor Data Structure and Storage

## Status: Completed

## Parent Issue: 901 - Rotor System

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

## Implementation Complete

### Changes Made

1. Added `RotorConnection` and `Rotor` structs to `src/020-board-data.h`
2. Added rotor array (rotors, rotor_count, rotor_capacity) to `BoardData`
3. Implemented management functions:
   - `board_data_add_rotor()` - Create rotor at grid position
   - `board_data_remove_rotor()` - Remove rotor by index
   - `board_data_rotor_add_connection()` - Manually add connection
   - `board_data_rotor_clear_connections()` - Clear all connections
   - `board_data_rotor_detect_connections()` - Auto-detect connected objects
4. Added JSON serialization in `board_data_load_json()` and `board_data_to_json_string()`
5. Updated `board_data_create()` and `board_data_destroy()` for memory management

### JSON Format Implemented

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

### Unblocks

- 901b (Editor tool for rotor placement)
- 901c (Rotation physics)
- 901d (Connected object detection)
