# 902a - Track Data Structure and Storage

## Status: Open

## Parent Issue: 902 - Track Mover System

## Problem

Need data structures to represent track networks with segments, intersections, and movers.

## Data Structures

```c
typedef struct TrackSegment {
    int id;
    int col1, row1;             // Start point (grid coords)
    int col2, row2;             // End point (grid coords)
    float length;               // Cached length in pixels

    // Connectivity (indices into track_segments array)
    int* connections_start;     // Segments connected at start
    int connections_start_count;
    int* connections_end;       // Segments connected at end
    int connections_end_count;
} TrackSegment;

typedef struct TrackIntersection {
    int col, row;               // Grid position
    int* segment_indices;       // Segments meeting here
    int segment_count;

    // Precomputed path selection
    // approach_paths[approach_segment_index] = array of valid exit segments
    int** approach_paths;
    int* approach_path_counts;
} TrackIntersection;

typedef struct TrackMover {
    int id;
    int current_segment;        // Which segment mover is on
    float position_on_segment;  // 0.0 to 1.0 along segment
    int direction;              // +1 or -1 (which way along segment)
    float speed;                // Units per second

    // Payload (connected objects)
    int* payload_indices;       // Indices into board objects
    int payload_count;
    Vector2* payload_offsets;   // Relative positions from mover
} TrackMover;

// Add to BoardData
typedef struct BoardData {
    // ... existing fields ...
    TrackSegment* track_segments;
    int track_segment_count;

    TrackIntersection* track_intersections;
    int track_intersection_count;

    TrackMover* track_movers;
    int track_mover_count;
} BoardData;
```

## JSON Format

```json
{
  "tracks": {
    "segments": [
      {"id": 0, "start": [5, 10], "end": [5, 15]},
      {"id": 1, "start": [5, 15], "end": [8, 15]},
      {"id": 2, "start": [5, 15], "end": [2, 18]}
    ],
    "movers": [
      {
        "segment": 0,
        "position": 0.0,
        "speed": 50,
        "payload": [3, 7, 12]
      }
    ]
  }
}
```

## Implementation Steps

1. Define TrackSegment, TrackIntersection, TrackMover structs
2. Add track arrays to BoardData
3. Implement segment creation/destruction
4. Implement intersection detection (find where segments share endpoints)
5. Implement approach path precomputation
6. Add JSON load/save

## Files to Modify

- `src/020-board-data.h` - Add track structs
- `src/021-board-data.c` - JSON serialization, intersection computation

## Notes

- Intersections are computed from segments, not stored directly in JSON
- Approach paths precomputed on load for performance
- Mover position is parametric (0-1) along segment for easy interpolation
