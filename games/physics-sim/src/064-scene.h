#ifndef SCENE_H
#define SCENE_H

// 064-scene.h
// Scene mode (issue 115): the game sets up one particular moment -- a few
// balls at exact positions and speeds, perhaps on an empty board -- instead
// of a normal game, optionally saves every frame, and quits after a set
// number of frames. Used to film a single mechanic for the lodge's gifs.
//
// Without any of the options the game runs exactly as it always has.

#define SCENE_MAX_BALLS 64
#define SCENE_PATH_MAX 512

// {{{ typedef struct SceneBall
// One ball the scene places. Positions are pixels from the top-left corner
// of the player's table; velocities are pixels per second.
typedef struct SceneBall {
    int owner;        // OWNER_PLAYER or OWNER_ADVERSARY
    float x, y;       // position relative to the player table's top-left
    float vx, vy;     // starting velocity
    float health;     // starting health (BALL_MAX_HEALTH when not given)
} SceneBall;
// }}}

// {{{ typedef struct SceneOptions
// Everything the command line asked for.
typedef struct SceneOptions {
    int active;                        // 1 when --scene was given
    char scene_path[SCENE_PATH_MAX];   // the scene file
    int clear_board;                   // 1 for "board empty", 0 for "board keep"
    SceneBall balls[SCENE_MAX_BALLS];
    int ball_count;

    int recording;                     // 1 when --record was given
    char record_dir[SCENE_PATH_MAX];   // where frames are saved
    int frame_limit;                   // quit after this many frames; 0 = never
} SceneOptions;
// }}}

// {{{ scene_parse_arguments
// Reads --scene FILE, --record DIR and --frames N, and loads the scene file.
// Returns 1 on success. On any problem prints what and where (file and line
// for a scene file) and returns 0; the caller must stop rather than run a
// half-understood scene.
int scene_parse_arguments(int argc, char* argv[], SceneOptions* options);
// }}}

// {{{ scene_write_goodbye
// Writes output/goodbye (relative to the working directory, which the run
// scripts set to the project folder): when the run ended and what it did.
// Called on every clean exit, so a missing or stale goodbye means a crash.
void scene_write_goodbye(const SceneOptions* options, int frames_drawn,
                         double seconds_run, int frames_recorded,
                         int balls_active);
// }}}

#endif // SCENE_H
