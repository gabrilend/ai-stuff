// src/021-board-data.c
// Board data implementation with JSON serialization
// Uses cJSON library for parsing and generating JSON

#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include "020-board-data.h"
#include "cJSON.h"

#define INITIAL_CAPACITY 32

// =============================================================================
// BoardData Creation and Destruction
// =============================================================================

// {{{ board_data_create
BoardData* board_data_create(int grid_cols, int grid_rows, int cell_size) {
    BoardData* data = (BoardData*)calloc(1, sizeof(BoardData));
    if (!data) {
        fprintf(stderr, "ERROR: Failed to allocate BoardData\n");
        return NULL;
    }

    data->version = 1;
    strcpy(data->name, "Untitled");

    data->cell_size = cell_size;
    data->grid_cols = grid_cols;
    data->grid_rows = grid_rows;
    data->board_width = grid_cols * cell_size;
    data->board_height = grid_rows * cell_size;

    // Allocate object array
    data->object_capacity = INITIAL_CAPACITY;
    data->objects = (BoardObject*)calloc(data->object_capacity, sizeof(BoardObject));
    if (!data->objects) {
        fprintf(stderr, "ERROR: Failed to allocate object array\n");
        free(data);
        return NULL;
    }
    data->object_count = 0;

    // Allocate zone array
    data->zone_capacity = INITIAL_CAPACITY;
    data->zones = (BoardZone*)calloc(data->zone_capacity, sizeof(BoardZone));
    if (!data->zones) {
        fprintf(stderr, "ERROR: Failed to allocate zone array\n");
        free(data->objects);
        free(data);
        return NULL;
    }
    data->zone_count = 0;

    return data;
}
// }}}

// {{{ board_data_destroy
void board_data_destroy(BoardData* data) {
    if (!data) return;

    if (data->objects) {
        free(data->objects);
    }
    if (data->zones) {
        free(data->zones);
    }
    free(data);
}
// }}}

// =============================================================================
// Internal Helpers
// =============================================================================

// {{{ ensure_object_capacity
static int ensure_object_capacity(BoardData* data) {
    if (data->object_count < data->object_capacity) {
        return 1;  // Already have room
    }

    int new_capacity = data->object_capacity * 2;
    BoardObject* new_objects = (BoardObject*)realloc(
        data->objects, new_capacity * sizeof(BoardObject));

    if (!new_objects) {
        fprintf(stderr, "ERROR: Failed to grow object array\n");
        return 0;
    }

    data->objects = new_objects;
    data->object_capacity = new_capacity;
    return 1;
}
// }}}

// {{{ ensure_zone_capacity
static int ensure_zone_capacity(BoardData* data) {
    if (data->zone_count < data->zone_capacity) {
        return 1;
    }

    int new_capacity = data->zone_capacity * 2;
    BoardZone* new_zones = (BoardZone*)realloc(
        data->zones, new_capacity * sizeof(BoardZone));

    if (!new_zones) {
        fprintf(stderr, "ERROR: Failed to grow zone array\n");
        return 0;
    }

    data->zones = new_zones;
    data->zone_capacity = new_capacity;
    return 1;
}
// }}}

// =============================================================================
// Object Management
// =============================================================================

// {{{ board_data_add_peg
int board_data_add_peg(BoardData* data, int col, int row) {
    return board_data_add_peg_ex(data, col, row,
                                  DEFAULT_RESTITUTION,
                                  DEFAULT_FRICTION,
                                  DEFAULT_POINT_BONUS);
}
// }}}

// {{{ board_data_add_peg_ex
int board_data_add_peg_ex(BoardData* data, int col, int row,
                          unsigned char restitution, unsigned char friction,
                          unsigned char point_bonus) {
    if (!data) return 0;
    if (!ensure_object_capacity(data)) return 0;

    BoardObject* obj = &data->objects[data->object_count];
    obj->type = OBJECT_PEG;
    obj->col = col;
    obj->row = row;
    obj->radius = 12.0f;  // Default peg radius
    obj->end_col = 0;
    obj->end_row = 0;
    obj->thickness = 0;
    obj->restitution = restitution;
    obj->friction = friction;
    obj->point_bonus = point_bonus;

    data->object_count++;
    return 1;
}
// }}}

// {{{ board_data_add_line
int board_data_add_line(BoardData* data, int start_col, int start_row,
                        int end_col, int end_row, float thickness) {
    return board_data_add_line_ex(data, start_col, start_row,
                                   end_col, end_row, thickness,
                                   DEFAULT_RESTITUTION,
                                   DEFAULT_FRICTION,
                                   DEFAULT_POINT_BONUS);
}
// }}}

// {{{ board_data_add_line_ex
int board_data_add_line_ex(BoardData* data, int start_col, int start_row,
                           int end_col, int end_row, float thickness,
                           unsigned char restitution, unsigned char friction,
                           unsigned char point_bonus) {
    if (!data) return 0;
    if (!ensure_object_capacity(data)) return 0;

    BoardObject* obj = &data->objects[data->object_count];
    obj->type = OBJECT_LINE;
    obj->col = start_col;
    obj->row = start_row;
    obj->radius = 0;
    obj->end_col = end_col;
    obj->end_row = end_row;
    obj->thickness = thickness;
    obj->restitution = restitution;
    obj->friction = friction;
    obj->point_bonus = point_bonus;

    data->object_count++;
    return 1;
}
// }}}

// {{{ board_data_has_object_at
int board_data_has_object_at(BoardData* data, int col, int row) {
    return board_data_get_object_at(data, col, row) != NULL;
}
// }}}

// {{{ board_data_get_object_at
BoardObject* board_data_get_object_at(BoardData* data, int col, int row) {
    if (!data) return NULL;

    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];

        if (obj->type == OBJECT_PEG) {
            if (obj->col == col && obj->row == row) {
                return obj;
            }
        } else if (obj->type == OBJECT_LINE) {
            // Check if point is on the line segment (grid coordinates)
            // For simplicity, check if it's the start or end point
            // A more thorough check would test points along the line
            if ((obj->col == col && obj->row == row) ||
                (obj->end_col == col && obj->end_row == row)) {
                return obj;
            }
        }
    }

    return NULL;
}
// }}}

// {{{ board_data_remove_object_at
int board_data_remove_object_at(BoardData* data, int col, int row) {
    if (!data) return 0;

    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];
        int found = 0;

        if (obj->type == OBJECT_PEG) {
            found = (obj->col == col && obj->row == row);
        } else if (obj->type == OBJECT_LINE) {
            found = ((obj->col == col && obj->row == row) ||
                     (obj->end_col == col && obj->end_row == row));
        }

        if (found) {
            // Shift remaining objects down
            for (int j = i; j < data->object_count - 1; j++) {
                data->objects[j] = data->objects[j + 1];
            }
            data->object_count--;
            return 1;
        }
    }

    return 0;
}
// }}}

// =============================================================================
// Zone Management
// =============================================================================

// {{{ board_data_add_score_zone
int board_data_add_score_zone(BoardData* data, int col, int row,
                              int width, int height, int points, int multiplier) {
    if (!data) return 0;
    if (!ensure_zone_capacity(data)) return 0;

    BoardZone* zone = &data->zones[data->zone_count];
    zone->type = ZONE_SCORE;
    zone->col = col;
    zone->row = row;
    zone->width = width;
    zone->height = height;
    zone->points = points;
    zone->multiplier = multiplier;
    zone->channel = 0;
    zone->direction = PORTAL_ENTRY;

    data->zone_count++;
    return 1;
}
// }}}

// {{{ board_data_add_portal
int board_data_add_portal(BoardData* data, int col, int row,
                          int width, int height, int channel,
                          PortalDirection direction) {
    if (!data) return 0;
    if (!ensure_zone_capacity(data)) return 0;

    BoardZone* zone = &data->zones[data->zone_count];
    zone->type = ZONE_PORTAL;
    zone->col = col;
    zone->row = row;
    zone->width = width;
    zone->height = height;
    zone->points = 0;
    zone->multiplier = 0;
    zone->channel = channel;
    zone->direction = direction;

    data->zone_count++;
    return 1;
}
// }}}

// {{{ board_data_remove_zone_at
int board_data_remove_zone_at(BoardData* data, int col, int row) {
    if (!data) return 0;

    for (int i = 0; i < data->zone_count; i++) {
        BoardZone* zone = &data->zones[i];

        // Check if point is within zone bounds
        if (col >= zone->col && col < zone->col + zone->width &&
            row >= zone->row && row < zone->row + zone->height) {
            // Shift remaining zones down
            for (int j = i; j < data->zone_count - 1; j++) {
                data->zones[j] = data->zones[j + 1];
            }
            data->zone_count--;
            return 1;
        }
    }

    return 0;
}
// }}}

// =============================================================================
// Property Conversion
// =============================================================================

// {{{ property_to_float
float property_to_float(unsigned char value) {
    return (float)value / 255.0f;
}
// }}}

// {{{ float_to_property
unsigned char float_to_property(float value) {
    if (value < 0.0f) value = 0.0f;
    if (value > 1.0f) value = 1.0f;
    return (unsigned char)(value * 255.0f);
}
// }}}

// =============================================================================
// JSON Loading
// =============================================================================

// {{{ board_data_load_json
BoardData* board_data_load_json(const char* filename) {
    // Read file contents
    FILE* file = fopen(filename, "r");
    if (!file) {
        fprintf(stderr, "ERROR: Cannot open board file: %s\n", filename);
        return NULL;
    }

    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);

    char* json_string = (char*)malloc(length + 1);
    if (!json_string) {
        fprintf(stderr, "ERROR: Cannot allocate memory for JSON\n");
        fclose(file);
        return NULL;
    }

    size_t read_len = fread(json_string, 1, length, file);
    json_string[read_len] = '\0';
    fclose(file);

    // Parse JSON
    cJSON* root = cJSON_Parse(json_string);
    free(json_string);

    if (!root) {
        const char* error = cJSON_GetErrorPtr();
        fprintf(stderr, "ERROR: JSON parse error: %s\n", error ? error : "unknown");
        return NULL;
    }

    // Extract grid settings
    cJSON* grid = cJSON_GetObjectItem(root, "grid");
    if (!grid) {
        fprintf(stderr, "ERROR: Missing 'grid' in JSON\n");
        cJSON_Delete(root);
        return NULL;
    }

    cJSON* cell_size_json = cJSON_GetObjectItem(grid, "cell_size");
    cJSON* cols_json = cJSON_GetObjectItem(grid, "columns");
    cJSON* rows_json = cJSON_GetObjectItem(grid, "rows");

    int cell_size = cell_size_json ? cell_size_json->valueint : 60;
    int cols = cols_json ? cols_json->valueint : 14;
    int rows = rows_json ? rows_json->valueint : 12;

    // Create board data
    BoardData* data = board_data_create(cols, rows, cell_size);
    if (!data) {
        cJSON_Delete(root);
        return NULL;
    }

    // Extract name
    cJSON* name = cJSON_GetObjectItem(root, "name");
    if (name && cJSON_IsString(name)) {
        strncpy(data->name, name->valuestring, 63);
        data->name[63] = '\0';
    }

    // Extract version
    cJSON* version = cJSON_GetObjectItem(root, "version");
    if (version && cJSON_IsNumber(version)) {
        data->version = version->valueint;
    }

    // Parse objects array
    cJSON* objects = cJSON_GetObjectItem(root, "objects");
    if (objects && cJSON_IsArray(objects)) {
        cJSON* obj_json;
        cJSON_ArrayForEach(obj_json, objects) {
            cJSON* type_json = cJSON_GetObjectItem(obj_json, "type");
            if (!type_json || !cJSON_IsString(type_json)) continue;

            const char* type_str = type_json->valuestring;

            cJSON* col_json = cJSON_GetObjectItem(obj_json, "col");
            cJSON* row_json = cJSON_GetObjectItem(obj_json, "row");
            int col = col_json ? col_json->valueint : 0;
            int row = row_json ? row_json->valueint : 0;

            // Get RGB properties (use defaults if not specified)
            cJSON* rest_json = cJSON_GetObjectItem(obj_json, "restitution");
            cJSON* fric_json = cJSON_GetObjectItem(obj_json, "friction");
            cJSON* bonus_json = cJSON_GetObjectItem(obj_json, "point_bonus");

            unsigned char restitution = rest_json ? (unsigned char)rest_json->valueint : DEFAULT_RESTITUTION;
            unsigned char friction = fric_json ? (unsigned char)fric_json->valueint : DEFAULT_FRICTION;
            unsigned char point_bonus = bonus_json ? (unsigned char)bonus_json->valueint : DEFAULT_POINT_BONUS;

            if (strcmp(type_str, "peg") == 0) {
                board_data_add_peg_ex(data, col, row, restitution, friction, point_bonus);
            } else if (strcmp(type_str, "line") == 0) {
                cJSON* end_col_json = cJSON_GetObjectItem(obj_json, "end_col");
                cJSON* end_row_json = cJSON_GetObjectItem(obj_json, "end_row");
                cJSON* thickness_json = cJSON_GetObjectItem(obj_json, "thickness");

                int end_col = end_col_json ? end_col_json->valueint : col;
                int end_row = end_row_json ? end_row_json->valueint : row;
                float thickness = thickness_json ? (float)thickness_json->valuedouble : 20.0f;

                board_data_add_line_ex(data, col, row, end_col, end_row, thickness,
                                       restitution, friction, point_bonus);
            }
        }
    }

    // Parse zones array
    cJSON* zones = cJSON_GetObjectItem(root, "zones");
    if (zones && cJSON_IsArray(zones)) {
        cJSON* zone_json;
        cJSON_ArrayForEach(zone_json, zones) {
            cJSON* type_json = cJSON_GetObjectItem(zone_json, "type");
            if (!type_json || !cJSON_IsString(type_json)) continue;

            const char* type_str = type_json->valuestring;

            cJSON* col_json = cJSON_GetObjectItem(zone_json, "col");
            cJSON* row_json = cJSON_GetObjectItem(zone_json, "row");
            cJSON* width_json = cJSON_GetObjectItem(zone_json, "width");
            cJSON* height_json = cJSON_GetObjectItem(zone_json, "height");

            int col = col_json ? col_json->valueint : 0;
            int row = row_json ? row_json->valueint : 0;
            int width = width_json ? width_json->valueint : 1;
            int height = height_json ? height_json->valueint : 1;

            if (strcmp(type_str, "score") == 0) {
                cJSON* points_json = cJSON_GetObjectItem(zone_json, "points");
                cJSON* mult_json = cJSON_GetObjectItem(zone_json, "multiplier");

                int points = points_json ? points_json->valueint : 100;
                int multiplier = mult_json ? mult_json->valueint : 1;

                board_data_add_score_zone(data, col, row, width, height, points, multiplier);
            } else if (strcmp(type_str, "portal") == 0) {
                cJSON* channel_json = cJSON_GetObjectItem(zone_json, "channel");
                cJSON* dir_json = cJSON_GetObjectItem(zone_json, "direction");

                int channel = channel_json ? channel_json->valueint : 1;
                PortalDirection dir = PORTAL_ENTRY;
                if (dir_json && cJSON_IsString(dir_json)) {
                    if (strcmp(dir_json->valuestring, "exit") == 0) {
                        dir = PORTAL_EXIT;
                    }
                }

                board_data_add_portal(data, col, row, width, height, channel, dir);
            }
        }
    }

    cJSON_Delete(root);
    printf("Loaded board: %s (%d objects, %d zones)\n",
           data->name, data->object_count, data->zone_count);

    return data;
}
// }}}

// =============================================================================
// JSON Saving
// =============================================================================

// {{{ board_data_to_json_string
char* board_data_to_json_string(BoardData* data) {
    if (!data) return NULL;

    cJSON* root = cJSON_CreateObject();

    // Version and name
    cJSON_AddNumberToObject(root, "version", data->version);
    cJSON_AddStringToObject(root, "name", data->name);

    // Grid settings
    cJSON* grid = cJSON_CreateObject();
    cJSON_AddNumberToObject(grid, "cell_size", data->cell_size);
    cJSON_AddNumberToObject(grid, "columns", data->grid_cols);
    cJSON_AddNumberToObject(grid, "rows", data->grid_rows);
    cJSON_AddItemToObject(root, "grid", grid);

    // Board dimensions
    cJSON* board = cJSON_CreateObject();
    cJSON_AddNumberToObject(board, "width", data->board_width);
    cJSON_AddNumberToObject(board, "height", data->board_height);
    cJSON_AddItemToObject(root, "board", board);

    // Objects array
    cJSON* objects = cJSON_CreateArray();
    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];
        cJSON* obj_json = cJSON_CreateObject();

        if (obj->type == OBJECT_PEG) {
            cJSON_AddStringToObject(obj_json, "type", "peg");
            cJSON_AddNumberToObject(obj_json, "col", obj->col);
            cJSON_AddNumberToObject(obj_json, "row", obj->row);
        } else if (obj->type == OBJECT_LINE) {
            cJSON_AddStringToObject(obj_json, "type", "line");
            cJSON_AddNumberToObject(obj_json, "col", obj->col);
            cJSON_AddNumberToObject(obj_json, "row", obj->row);
            cJSON_AddNumberToObject(obj_json, "end_col", obj->end_col);
            cJSON_AddNumberToObject(obj_json, "end_row", obj->end_row);
            cJSON_AddNumberToObject(obj_json, "thickness", obj->thickness);
        }

        // RGB properties (only if non-default)
        if (obj->restitution != DEFAULT_RESTITUTION) {
            cJSON_AddNumberToObject(obj_json, "restitution", obj->restitution);
        }
        if (obj->friction != DEFAULT_FRICTION) {
            cJSON_AddNumberToObject(obj_json, "friction", obj->friction);
        }
        if (obj->point_bonus != DEFAULT_POINT_BONUS) {
            cJSON_AddNumberToObject(obj_json, "point_bonus", obj->point_bonus);
        }

        cJSON_AddItemToArray(objects, obj_json);
    }
    cJSON_AddItemToObject(root, "objects", objects);

    // Zones array
    cJSON* zones = cJSON_CreateArray();
    for (int i = 0; i < data->zone_count; i++) {
        BoardZone* zone = &data->zones[i];
        cJSON* zone_json = cJSON_CreateObject();

        if (zone->type == ZONE_SCORE) {
            cJSON_AddStringToObject(zone_json, "type", "score");
            cJSON_AddNumberToObject(zone_json, "col", zone->col);
            cJSON_AddNumberToObject(zone_json, "row", zone->row);
            cJSON_AddNumberToObject(zone_json, "width", zone->width);
            cJSON_AddNumberToObject(zone_json, "height", zone->height);
            cJSON_AddNumberToObject(zone_json, "points", zone->points);
            cJSON_AddNumberToObject(zone_json, "multiplier", zone->multiplier);
        } else if (zone->type == ZONE_PORTAL) {
            cJSON_AddStringToObject(zone_json, "type", "portal");
            cJSON_AddNumberToObject(zone_json, "col", zone->col);
            cJSON_AddNumberToObject(zone_json, "row", zone->row);
            cJSON_AddNumberToObject(zone_json, "width", zone->width);
            cJSON_AddNumberToObject(zone_json, "height", zone->height);
            cJSON_AddNumberToObject(zone_json, "channel", zone->channel);
            cJSON_AddStringToObject(zone_json, "direction",
                zone->direction == PORTAL_ENTRY ? "entry" : "exit");
        }

        cJSON_AddItemToArray(zones, zone_json);
    }
    cJSON_AddItemToObject(root, "zones", zones);

    // Generate formatted JSON string
    char* json_string = cJSON_Print(root);
    cJSON_Delete(root);

    return json_string;
}
// }}}

// {{{ board_data_save_json
int board_data_save_json(BoardData* data, const char* filename) {
    char* json_string = board_data_to_json_string(data);
    if (!json_string) {
        fprintf(stderr, "ERROR: Failed to serialize board data\n");
        return 0;
    }

    FILE* file = fopen(filename, "w");
    if (!file) {
        fprintf(stderr, "ERROR: Cannot open file for writing: %s\n", filename);
        free(json_string);
        return 0;
    }

    fputs(json_string, file);
    fclose(file);
    free(json_string);

    printf("Board saved to: %s\n", filename);
    return 1;
}
// }}}

// =============================================================================
// Board Loading (BoardData -> Game World)
// =============================================================================

#include "004-world.h"
#include "022-grid.h"

// {{{ rgb_to_color
// Converts RGB properties to a visual Color.
// R=restitution maps to red intensity, G=friction to green, B=point_bonus to blue.
static Color rgb_to_color(unsigned char r, unsigned char g, unsigned char b) {
    // Base steel color, tinted by properties
    // Higher restitution = more red/orange (bouncy)
    // Higher friction = more green (grippy)
    // Higher point_bonus = more blue (valuable)
    int red = 140 + (r * 115 / 255);    // 140-255
    int green = 140 + (g * 60 / 255);   // 140-200
    int blue = 140 + (b * 115 / 255);   // 140-255

    return (Color){(unsigned char)red, (unsigned char)green, (unsigned char)blue, 255};
}
// }}}

// {{{ board_data_apply_pegs_to_world
void board_data_apply_pegs_to_world(BoardData* data, struct World* world,
                                    struct Grid* grid) {
    if (!data || !world || !grid) return;

    // Count pegs in BoardData
    int peg_count = 0;
    for (int i = 0; i < data->object_count; i++) {
        if (data->objects[i].type == OBJECT_PEG) {
            peg_count++;
        }
    }

    if (peg_count == 0) {
        // No pegs to add - clear existing
        if (world->pegs) {
            free(world->pegs);
            world->pegs = NULL;
        }
        world->peg_count = 0;
        return;
    }

    // Free existing pegs
    if (world->pegs) {
        free(world->pegs);
    }

    // Allocate new peg array
    world->pegs = (Peg*)malloc(sizeof(Peg) * peg_count);
    if (!world->pegs) {
        fprintf(stderr, "ERROR: Failed to allocate pegs from board data\n");
        world->peg_count = 0;
        return;
    }
    world->peg_count = peg_count;

    // Convert BoardObjects to Pegs
    int peg_idx = 0;
    for (int i = 0; i < data->object_count; i++) {
        BoardObject* obj = &data->objects[i];
        if (obj->type != OBJECT_PEG) continue;

        Peg* peg = &world->pegs[peg_idx];

        // Convert grid position to pixel position
        peg->x = grid_to_pixel_x(grid, obj->col, obj->row);
        peg->y = grid_to_pixel_y(grid, obj->col, obj->row);
        peg->radius = PEG_RADIUS;

        // Convert RGB properties
        peg->restitution = property_to_float(obj->restitution);
        peg->friction = property_to_float(obj->friction);
        peg->point_bonus = obj->point_bonus;

        // Generate color from RGB properties
        peg->color = rgb_to_color(obj->restitution, obj->friction, obj->point_bonus);

        peg_idx++;
    }

    printf("Applied %d pegs from board data\n", peg_count);
}
// }}}

// {{{ board_data_apply_zones_to_world
void board_data_apply_zones_to_world(BoardData* data, struct World* world,
                                     struct Grid* grid) {
    if (!data || !world || !grid) return;

    // Count score zones in BoardData (portals handled separately)
    int zone_count = 0;
    for (int i = 0; i < data->zone_count; i++) {
        if (data->zones[i].type == ZONE_SCORE) {
            zone_count++;
        }
    }

    if (zone_count == 0) {
        // No zones to add - clear existing
        if (world->zones) {
            free(world->zones);
            world->zones = NULL;
        }
        world->zone_count = 0;
        return;
    }

    // Free existing zones
    if (world->zones) {
        free(world->zones);
    }

    // Allocate new zone array
    world->zones = (ScoreZone*)malloc(sizeof(ScoreZone) * zone_count);
    if (!world->zones) {
        fprintf(stderr, "ERROR: Failed to allocate zones from board data\n");
        world->zone_count = 0;
        return;
    }
    world->zone_count = zone_count;

    // Convert BoardZones to ScoreZones
    int zone_idx = 0;
    for (int i = 0; i < data->zone_count; i++) {
        BoardZone* bz = &data->zones[i];
        if (bz->type != ZONE_SCORE) continue;

        ScoreZone* sz = &world->zones[zone_idx];

        // Convert grid bounds to pixel bounds
        // Zone starts at top-left of grid cell
        float cell_x = grid->origin_x + bz->col * grid->cell_size;
        float cell_y = grid->origin_y + bz->row * grid->cell_size;

        sz->x_min = cell_x;
        sz->x_max = cell_x + bz->width * grid->cell_size;
        sz->y_min = cell_y;
        sz->y_max = cell_y + bz->height * grid->cell_size;
        sz->points = bz->points * bz->multiplier;

        zone_idx++;
    }

    printf("Applied %d score zones from board data\n", zone_count);
}
// }}}

// {{{ board_data_apply_to_world
void board_data_apply_to_world(BoardData* data, struct World* world,
                               struct Grid* grid) {
    if (!data || !world || !grid) return;

    // Apply pegs
    board_data_apply_pegs_to_world(data, world, grid);

    // Apply score zones
    board_data_apply_zones_to_world(data, world, grid);

    // Note: Lines (ramps) and portals require additional systems
    // and will be handled by separate issues (1110, 1112)

    printf("Board data applied to world: %s\n", data->name);
}
// }}}

// =============================================================================
// Directory Scanning
// =============================================================================

// {{{ board_scan_directory
BoardFileList* board_scan_directory(const char* directory) {
    BoardFileList* list = (BoardFileList*)malloc(sizeof(BoardFileList));
    if (!list) return NULL;

    list->count = 0;
    list->capacity = 16;
    list->filenames = (char**)malloc(sizeof(char*) * list->capacity);
    if (!list->filenames) {
        free(list);
        return NULL;
    }

    DIR* dir = opendir(directory);
    if (!dir) {
        fprintf(stderr, "WARNING: Cannot open directory: %s\n", directory);
        return list;  // Return empty list
    }

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        // Check for .json extension
        const char* name = entry->d_name;
        size_t len = strlen(name);
        if (len > 5 && strcmp(name + len - 5, ".json") == 0) {
            // Grow array if needed
            if (list->count >= list->capacity) {
                list->capacity *= 2;
                list->filenames = (char**)realloc(list->filenames,
                                                   sizeof(char*) * list->capacity);
            }

            // Store filename
            list->filenames[list->count] = strdup(name);
            list->count++;
        }
    }

    closedir(dir);
    printf("Found %d board files in %s\n", list->count, directory);
    return list;
}
// }}}

// {{{ board_file_list_destroy
void board_file_list_destroy(BoardFileList* list) {
    if (!list) return;

    for (int i = 0; i < list->count; i++) {
        free(list->filenames[i]);
    }
    free(list->filenames);
    free(list);
}
// }}}
