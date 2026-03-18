// src/020-board-data.h
// Board data structures for JSON-based level storage
// Defines objects (pegs, lines) and zones (gates, portals) with RGB properties

#ifndef BOARD_DATA_H
#define BOARD_DATA_H

// =============================================================================
// Object Types
// =============================================================================

// {{{ ObjectType enum
typedef enum ObjectType {
    OBJECT_PEG,
    OBJECT_LINE,
    OBJECT_COUNT
} ObjectType;
// }}}

// {{{ ZoneType enum
typedef enum ZoneType {
    ZONE_SCORE,
    ZONE_PORTAL,
    ZONE_COUNT
} ZoneType;
// }}}

// {{{ PortalDirection enum
typedef enum PortalDirection {
    PORTAL_ENTRY,
    PORTAL_EXIT
} PortalDirection;
// }}}

// =============================================================================
// Default Property Values
// =============================================================================

#define DEFAULT_RESTITUTION 178   // ~0.7 (maps to 0-255)
#define DEFAULT_FRICTION 51       // ~0.2 (maps to 0-255)
#define DEFAULT_POINT_BONUS 0     // No bonus points

// =============================================================================
// Data Structures
// =============================================================================

// {{{ typedef struct BoardObject
// BoardObject represents a collision obstacle in the board.
// Can be a peg (circle) or line (thick segment with rounded ends).
// RGB properties control physics behavior and visual color.
typedef struct BoardObject {
    ObjectType type;

    // Grid position (peg: center, line: start point)
    int col, row;

    // For pegs
    float radius;

    // For lines
    int end_col, end_row;    // End grid position
    float thickness;         // Line thickness in pixels

    // RGB Properties (0-255 each)
    unsigned char restitution;  // R: bounciness (0=dead, 255=super bounce)
    unsigned char friction;     // G: surface grip (0=ice, 255=sticky)
    unsigned char point_bonus;  // B: points awarded on hit
} BoardObject;
// }}}

// {{{ typedef struct BoardZone
// BoardZone represents a trigger area in the board.
// Zones fire once per ball and reset when ball exits.
// Can be scoring gates or portal teleporters.
typedef struct BoardZone {
    ZoneType type;

    // Grid position (top-left corner)
    int col, row;

    // Size in grid cells
    int width, height;

    // For score zones
    int points;
    int multiplier;

    // For portal zones
    int channel;                  // Portals with same channel are linked
    PortalDirection direction;    // PORTAL_ENTRY or PORTAL_EXIT
} BoardZone;
// }}}

// {{{ typedef struct BoardData
// BoardData contains all data for a single stage/board.
// Loaded from JSON, converted to game objects at runtime.
typedef struct BoardData {
    int version;
    char name[64];

    // Grid settings
    int cell_size;
    int grid_cols;
    int grid_rows;

    // Board dimensions (pixels, derived from grid)
    int board_width;
    int board_height;

    // Editor flag - board is work in progress (issue 1224)
    // When true, board is excluded from random stage selection
    int in_progress;

    // Objects (collision obstacles)
    BoardObject* objects;
    int object_count;
    int object_capacity;

    // Zones (trigger areas)
    BoardZone* zones;
    int zone_count;
    int zone_capacity;
} BoardData;
// }}}

// =============================================================================
// BoardData Creation and Destruction
// =============================================================================

// {{{ board_data_create
// Creates an empty board with the given grid dimensions.
// Returns NULL on allocation failure.
BoardData* board_data_create(int grid_cols, int grid_rows, int cell_size);
// }}}

// {{{ board_data_destroy
// Frees all memory associated with a board.
void board_data_destroy(BoardData* data);
// }}}

// =============================================================================
// Object Management
// =============================================================================

// {{{ board_data_add_peg
// Adds a peg at the given grid position with default properties.
// Returns 1 on success, 0 on failure.
int board_data_add_peg(BoardData* data, int col, int row);
// }}}

// {{{ board_data_add_peg_ex
// Adds a peg with custom properties.
// Returns 1 on success, 0 on failure.
int board_data_add_peg_ex(BoardData* data, int col, int row,
                          unsigned char restitution, unsigned char friction,
                          unsigned char point_bonus);
// }}}

// {{{ board_data_add_line
// Adds a line from (start_col, start_row) to (end_col, end_row).
// Returns 1 on success, 0 on failure.
int board_data_add_line(BoardData* data, int start_col, int start_row,
                        int end_col, int end_row, float thickness);
// }}}

// {{{ board_data_add_line_ex
// Adds a line with custom properties.
// Returns 1 on success, 0 on failure.
int board_data_add_line_ex(BoardData* data, int start_col, int start_row,
                           int end_col, int end_row, float thickness,
                           unsigned char restitution, unsigned char friction,
                           unsigned char point_bonus);
// }}}

// {{{ board_data_remove_object_at
// Removes the object at the given grid position.
// For lines, removes if any part occupies the position.
// Returns 1 if object removed, 0 if no object found.
int board_data_remove_object_at(BoardData* data, int col, int row);
// }}}

// {{{ board_data_has_object_at
// Checks if there's an object at the given grid position.
// Returns 1 if occupied, 0 if empty.
int board_data_has_object_at(BoardData* data, int col, int row);
// }}}

// {{{ board_data_get_object_at
// Gets the object at the given grid position.
// Returns pointer to object, or NULL if no object found.
BoardObject* board_data_get_object_at(BoardData* data, int col, int row);
// }}}

// =============================================================================
// Zone Management
// =============================================================================

// {{{ board_data_add_score_zone
// Adds a scoring zone at the given grid position.
// Returns 1 on success, 0 on failure.
int board_data_add_score_zone(BoardData* data, int col, int row,
                              int width, int height, int points, int multiplier);
// }}}

// {{{ board_data_add_portal
// Adds a portal zone at the given grid position.
// Returns 1 on success, 0 on failure.
int board_data_add_portal(BoardData* data, int col, int row,
                          int width, int height, int channel,
                          PortalDirection direction);
// }}}

// {{{ board_data_remove_zone_at
// Removes the zone at the given grid position.
// Returns 1 if zone removed, 0 if no zone found.
int board_data_remove_zone_at(BoardData* data, int col, int row);
// }}}

// =============================================================================
// Property Conversion Utilities
// =============================================================================

// {{{ property_to_float
// Converts a 0-255 property value to 0.0-1.0 float.
float property_to_float(unsigned char value);
// }}}

// {{{ float_to_property
// Converts a 0.0-1.0 float to 0-255 property value.
unsigned char float_to_property(float value);
// }}}

// =============================================================================
// Directory Scanning
// =============================================================================

// {{{ typedef struct BoardFileList
// List of board JSON files found in a directory
typedef struct BoardFileList {
    char** filenames;  // Array of filename strings
    int count;         // Number of files
    int capacity;      // Allocated capacity
} BoardFileList;
// }}}

// {{{ board_scan_directory
// Scans a directory for .json files.
// Returns a BoardFileList (may be empty if no files found).
// Caller must call board_file_list_destroy when done.
BoardFileList* board_scan_directory(const char* directory);
// }}}

// {{{ board_file_list_destroy
// Frees a BoardFileList and all its strings.
void board_file_list_destroy(BoardFileList* list);
// }}}

// =============================================================================
// JSON Serialization
// =============================================================================

// {{{ board_data_load_json
// Loads board data from a JSON file.
// Returns NULL on failure (file not found, parse error, etc.)
BoardData* board_data_load_json(const char* filename);
// }}}

// {{{ board_data_save_json
// Saves board data to a JSON file.
// Returns 1 on success, 0 on failure.
int board_data_save_json(BoardData* data, const char* filename);
// }}}

// {{{ board_data_to_json_string
// Converts board data to a JSON string.
// Caller must free the returned string.
char* board_data_to_json_string(BoardData* data);
// }}}

// =============================================================================
// Board Loading (BoardData -> Game World)
// =============================================================================

// Forward declaration for World (defined in 004-world.h)
struct World;
struct Grid;

// {{{ board_data_apply_pegs_to_world
// Converts BoardData pegs to World pegs.
// Replaces existing pegs in the world.
// Parameters:
//   data: Board data containing peg objects
//   world: Target world to populate
//   grid: Grid for coordinate conversion
void board_data_apply_pegs_to_world(BoardData* data, struct World* world,
                                    struct Grid* grid);
// }}}

// {{{ board_data_apply_zones_to_world
// Converts BoardData zones to World zones.
// Only handles ZONE_SCORE types (portals handled separately).
// Replaces existing zones in the world.
// Parameters:
//   data: Board data containing zone definitions
//   world: Target world to populate
//   grid: Grid for coordinate conversion
void board_data_apply_zones_to_world(BoardData* data, struct World* world,
                                     struct Grid* grid);
// }}}

// {{{ board_data_apply_to_world
// Applies all BoardData content to a World.
// Converts pegs and score zones. Lines and portals require additional setup.
// Parameters:
//   data: Board data to apply
//   world: Target world to populate
//   grid: Grid for coordinate conversion
void board_data_apply_to_world(BoardData* data, struct World* world,
                               struct Grid* grid);
// }}}

// =============================================================================
// Validation
// =============================================================================

// {{{ board_data_validate_portals
// Validates portal channel consistency.
// Checks that any channel with entry portals also has exit portals.
// Parameters:
//   data: Board data to validate
//   orphan_channel: Output - first channel with entries but no exits (-1 if valid)
// Returns: 1 if valid, 0 if orphan channel found
int board_data_validate_portals(BoardData* data, int* orphan_channel);
// }}}

#endif // BOARD_DATA_H
