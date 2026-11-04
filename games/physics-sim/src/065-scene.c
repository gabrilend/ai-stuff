// 065-scene.c
// Scene mode (issue 115): reading the command line and the scene file, and
// writing the goodbye receipt. See 064-scene.h for what each piece is for.
//
// The scene file is read strictly. A scene exists to film one exact moment;
// a line that is silently skipped would film a different moment and nobody
// would know, so any line the reader does not understand stops the game
// with the file and line number.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "006-ball.h"
#include "064-scene.h"

// {{{ static int read_board_line()
// "board empty" clears both boards' pegs, lines and closed shapes, so only
// the scene's balls and the gates remain; "board keep" leaves the loaded
// board in place, for scenes about how balls meet the pegs.
static int read_board_line(const char* rest, SceneOptions* options) {
    char word[32];
    if (sscanf(rest, "%31s", word) != 1) {
        return 0;
    }
    if (strcmp(word, "empty") == 0) {
        options->clear_board = 1;
        return 1;
    }
    if (strcmp(word, "keep") == 0) {
        options->clear_board = 0;
        return 1;
    }
    return 0;
}
// }}}

// {{{ static int read_ball_line()
// "ball OWNER X Y VX VY [HEALTH]". OWNER is player or adversary; a ball with
// no HEALTH starts with the normal full health.
static int read_ball_line(const char* rest, SceneOptions* options) {
    if (options->ball_count >= SCENE_MAX_BALLS) {
        return 0;
    }
    char owner[32];
    SceneBall ball;
    ball.health = BALL_MAX_HEALTH;
    int read = sscanf(rest, "%31s %f %f %f %f %f",
                      owner, &ball.x, &ball.y, &ball.vx, &ball.vy, &ball.health);
    if (read < 5) {
        return 0;
    }
    if (strcmp(owner, "player") == 0) {
        ball.owner = OWNER_PLAYER;
    } else if (strcmp(owner, "adversary") == 0) {
        ball.owner = OWNER_ADVERSARY;
    } else {
        return 0;
    }
    options->balls[options->ball_count] = ball;
    options->ball_count++;
    return 1;
}
// }}}

// {{{ SCENE_WORDS -- the first word of each line a scene may contain
// A dispatch table rather than a chain of comparisons: a new kind of line is
// one new entry here and one reader above.
typedef struct SceneWord {
    const char* word;
    int (*read)(const char* rest, SceneOptions* options);
} SceneWord;

static const SceneWord SCENE_WORDS[] = {
    { "board", read_board_line },
    { "ball",  read_ball_line },
};
#define SCENE_WORD_COUNT (int)(sizeof(SCENE_WORDS) / sizeof(SCENE_WORDS[0]))
// }}}

// {{{ static int read_scene_file()
static int read_scene_file(SceneOptions* options) {
    FILE* file = fopen(options->scene_path, "r");
    if (!file) {
        fprintf(stderr, "ERROR: cannot open scene file %s\n", options->scene_path);
        return 0;
    }

    char line[512];
    int line_number = 0;
    int ok = 1;
    while (fgets(line, sizeof(line), file)) {
        line_number++;

        // a '#' starts a comment; blank lines are nothing
        char* hash = strchr(line, '#');
        if (hash) *hash = '\0';
        char word[32];
        int consumed = 0;
        if (sscanf(line, "%31s%n", word, &consumed) != 1) {
            continue;
        }

        int understood = 0;
        for (int i = 0; i < SCENE_WORD_COUNT; i++) {
            if (strcmp(word, SCENE_WORDS[i].word) == 0) {
                understood = SCENE_WORDS[i].read(line + consumed, options);
                break;
            }
        }
        if (!understood) {
            fprintf(stderr, "ERROR: %s:%d: a scene line the game does not understand: %s",
                    options->scene_path, line_number, line);
            ok = 0;
        }
    }
    fclose(file);

    if (ok && options->ball_count == 0) {
        fprintf(stderr, "ERROR: %s: a scene with no balls films nothing\n", options->scene_path);
        ok = 0;
    }
    return ok;
}
// }}}

// {{{ int scene_parse_arguments()
int scene_parse_arguments(int argc, char* argv[], SceneOptions* options) {
    memset(options, 0, sizeof(*options));
    options->clear_board = 1;

    for (int i = 1; i < argc; i++) {
        int has_value = (i + 1 < argc);
        if (strcmp(argv[i], "--scene") == 0 && has_value) {
            options->active = 1;
            snprintf(options->scene_path, SCENE_PATH_MAX, "%s", argv[++i]);
        } else if (strcmp(argv[i], "--record") == 0 && has_value) {
            options->recording = 1;
            snprintf(options->record_dir, SCENE_PATH_MAX, "%s", argv[++i]);
        } else if (strcmp(argv[i], "--frames") == 0 && has_value) {
            options->frame_limit = atoi(argv[++i]);
            if (options->frame_limit <= 0) {
                fprintf(stderr, "ERROR: --frames needs a positive number, got %s\n", argv[i]);
                return 0;
            }
        } else {
            fprintf(stderr, "ERROR: unknown option %s (known: --scene FILE, --record DIR, --frames N)\n",
                    argv[i]);
            return 0;
        }
    }

    if (options->active) {
        return read_scene_file(options);
    }
    return 1;
}
// }}}

// {{{ void scene_write_goodbye()
void scene_write_goodbye(const SceneOptions* options, int frames_drawn,
                         double seconds_run, int frames_recorded,
                         int balls_active) {
    FILE* file = fopen("output/goodbye", "w");
    if (!file) {
        fprintf(stderr, "ERROR: cannot write output/goodbye (run from the project folder)\n");
        return;
    }
    char ended[64];
    time_t now = time(NULL);
    strftime(ended, sizeof(ended), "%Y-%m-%d %H:%M:%S", localtime(&now));

    fprintf(file, "goodbye from physics-sim\n");
    fprintf(file, "ended: %s\n", ended);
    fprintf(file, "mode: %s\n", options->active ? "scene" : "game");
    if (options->active) {
        fprintf(file, "scene: %s\n", options->scene_path);
    }
    fprintf(file, "frames drawn: %d\n", frames_drawn);
    fprintf(file, "seconds run: %.2f\n", seconds_run);
    fprintf(file, "frames recorded: %d\n", frames_recorded);
    fprintf(file, "balls active at the end: %d\n", balls_active);
    fclose(file);
}
// }}}
