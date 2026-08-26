/*
 * 073-rules.h -- the part that is allowed to have opinions.
 *
 * The server knows about space, sight, things, and permission. It does not know
 * what a saving throw is. Everything game-specific lives in a RULESET, which is
 * a directory of Lua loaded at startup the way a font is loaded.
 *
 * A ruleset is not a plugin: it never executes machine code, and it reaches the
 * world only through the accessors registered here.
 *
 * THE EXCLUSIONS ARE THE POINT. The security argument in
 * docs/009-what-a-viewer-is-allowed-to-know.md has to survive a carelessly
 * written ruleset, so a ruleset is never in a position to break it. It can
 * decide what a sheet field MEANS. It cannot decide whether a socket gets bytes.
 *
 * See docs/011-the-rules-layer.md and issues 701 through 709.
 */

#ifndef VTT_RULES_H
#define VTT_RULES_H

#include <stdint.h>

#include "049-tick.h"
#include "051-commandlog.h"

/* The hooks. A ruleset provides what it cares about; the rest are absent. */
#define HOOK_ON_LOAD          0
#define HOOK_ON_COMMAND       1
#define HOOK_ON_ACTION        2
#define HOOK_ON_TICK          3
#define HOOK_ON_REGION_ENTER  4
#define HOOK_ON_INTERACT      5
#define HOOK_MAY_KNOW         6
#define HOOK_DESCRIBE         7
#define HOOK_COUNT            8

/*
 * How many times one hook may fail before it is stopped.
 *
 * A hook that raises an error every beat fills a log and drowns a session. Past
 * this it is not called again and that is said once, loudly -- a ruleset that is
 * broken should be visibly broken rather than continuously noisy.
 */
#define HOOK_FAILURE_LIMIT 8

/* What a ruleset asked the server to do. Requests, checked like anybody's. */
#define REQUEST_MOVE        1u
#define REQUEST_SET_HIDDEN  2u
#define REQUEST_SET_KIND    3u

struct rule_request {
    uint8_t  kind;
    uint32_t thing;
    int32_t  ax;
    int32_t  ay;
};

#define RULES_MAX_REQUESTS 256

struct ruleset {
    void *state;                 /* lua_State *, opaque here. */

    struct world *world;         /* Borrowed. */
    struct sim   *sim;           /* Borrowed -- for the tick number and streams. */

    int      hook[HOOK_COUNT];   /* Registry references, or absent. */
    uint8_t  present[HOOK_COUNT];
    uint32_t failures[HOOK_COUNT];
    uint8_t  abandoned[HOOK_COUNT];

    /*
     * Requests are queued and drained AFTER a hook returns, so a ruleset cannot
     * mutate the world underneath a pass that is iterating it -- and so that an
     * erroring hook's half-applied requests can be discarded whole.
     */
    struct rule_request requests[RULES_MAX_REQUESTS];
    uint32_t            request_count;

    /* What the last failure said, for a demo or a log. */
    char last_error[256];

    /* What the last refusal said. A sentence the ruleset wrote. */
    char last_refusal[256];

    uint32_t loaded_files;
};

/*
 * Start a ruleset over a world. `directory` holds .lua files, loaded in numeric
 * order -- the same discipline as the source, so reading from the lowest number
 * is the story.
 *
 * Returns 1 on success. On failure `why` holds a sentence naming the file and
 * the line, and the caller must REFUSE TO START: a server running with half a
 * ruleset is worse than one that would not start.
 */
int rules_load(struct ruleset *r, struct world *w, struct sim *sim,
               const char *directory, const char **why);

void rules_release(struct ruleset *r);

/* Whether a hook exists and has not been abandoned. */
int rules_has(const struct ruleset *r, int hook);

/*
 * Gate 6 of the gauntlet. Returns REFUSED_NOT_AT_ALL, or a refusal -- and when
 * refused, `r->last_refusal` holds the sentence the ruleset wrote.
 *
 * AN ERROR IS NOT A REFUSAL. A ruleset that raises has failed rather than
 * declined, and that is reported differently, because "you may not" and "the
 * rules are broken" send a person to look at different things.
 */
uint16_t rules_on_command(struct ruleset *r, uint32_t viewer,
                          const struct log_entry *entry);

/* Pass 5 of the tick. */
void rules_on_tick(struct ruleset *r);

/* A body crossed a boundary. Delivered in index order, on one thread. */
void rules_on_region_enter(struct ruleset *r, uint32_t thing,
                           uint32_t left, uint32_t entered);

/*
 * Which sheet fields this viewer may be told about this thing, as a comma-joined
 * list written into `into`. Empty when there is no hook -- adding a rules layer
 * must not widen what is sent by default.
 *
 * Runs AFTER the four existing gates, on records already approved. It can only
 * narrow, never widen.
 */
void rules_may_know(struct ruleset *r, uint32_t viewer, uint32_t thing,
                    char *into, uint32_t capacity);

/* What the view should be told about a kind's appearance. */
void rules_describe(struct ruleset *r, uint32_t kind, char *into, uint32_t capacity);

/* Everything game-specific arrives through this one door. */
uint16_t rules_on_action(struct ruleset *r, uint32_t viewer,
                         const struct log_entry *entry);

/* How many requests the last hook made, for a demo. */
uint32_t rules_requests_made(const struct ruleset *r);

/*
 * Whether this ruleset can put its sheets back after a rollback.
 *
 * IT CANNOT, and that is not hidden. A world snapshot copies flat blocks; a Lua
 * table is not that. So a rolled-back turn restores geometry and not hit points
 * -- a rollback that looks like it worked. See open question 14.1.
 */
int rules_sheets_survive_rollback(const struct ruleset *r);

#endif
