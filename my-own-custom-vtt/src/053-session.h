/*
 * 053-session.h -- turns, and taking one back.
 *
 * A turn is a TRANSACTION: a window in which declarations accumulate, a
 * simultaneous resolution when it closes, a snapshot at its head, and an undo.
 *
 * That is all the server understands about a turn. Not initiative, not rounds,
 * not whether acting twice is legal -- those are a ruleset's. A ruleset that
 * wants continuous play sets the window to one tick and never rolls anything
 * back, and none of the machinery below ever fires.
 *
 * UNDO DID NOT NEED A MECHANISM. It needed two mechanisms built for other
 * reasons to be aimed at each other: a snapshot is a copy of some bytes, because
 * the world is flat arrays with no pointers; and a replay lands in the same
 * place every time, because the tick is deterministic. Point those at each other
 * and you have rollback.
 *
 * See docs/019-the-turn-is-a-transaction.md and issues 308 and 309.
 */

#ifndef VTT_SESSION_H
#define VTT_SESSION_H

#include <stdint.h>

#include "049-tick.h"
#include "051-commandlog.h"
#include "044-fog.h"

/* What a window is doing. */
#define TURN_OPEN      0u
#define TURN_CLOSED    1u

/*
 * The two things people mean by undo.
 *
 * Re-declare is for a dropped connection or a misread situation: everybody gets
 * another go. Retcon is for a GM who ruled wrongly and wants everything
 * downstream to follow the correction -- and is the dangerous one, because it
 * changes what somebody did without asking them.
 */
#define ROLLBACK_REDECLARE 0u
#define ROLLBACK_RETCON    1u

/*
 * One turn's head, kept so it can be returned to.
 *
 * Everything that can differ between two runs is in here. Leaving the streams
 * out would make a retconned turn roll different dice for a reason nobody can
 * see -- which looks exactly like the retcon having worked, and is the hardest
 * kind of wrong to notice.
 */
struct turn_state {
    uint32_t turn;
    uint64_t tick;
    uint32_t log_position;

    struct world           world;
    struct stream_registry streams;

    struct order *orders;
    uint32_t      order_count;

    struct fog   *fogs;
    uint32_t      fog_count;

    uint8_t used;

    /*
     * Whether the ruleset's sheets were copied with the rest of it.
     *
     * A turn whose sheets could not be copied -- because one of them holds a
     * function, or points back at itself -- is NOT rollbackable. Not
     * half-rollbackable: restoring geometry and not hit points is a rollback
     * that looks like it worked, which is the thing this whole path exists to
     * avoid.
     *
     * The sentence saying which sheet and where is kept, because "that turn
     * cannot be taken back" is not an answer somebody can act on and "the goblin
     * at sheet 3 holds a function at .attack" is.
     */
    uint8_t sheets_copied;
    char    sheet_trouble[256];
};

struct turn_ring {
    struct turn_state *slots;
    uint32_t           depth;
    uint32_t           next;
};

struct session {
    struct world *world;      /* Borrowed. The ring holds full copies. */
    struct pool  *pool;       /* Borrowed. */

    struct sim         sim;
    struct command_log log;
    struct turn_ring   ring;

    /*
     * Per-viewer memory. Empty until phase 4 gives the session viewers; the
     * snapshot path is wired now so that adding them later is adding an array
     * rather than finding every place a fog is touched.
     */
    struct fog *fogs;
    uint32_t    fog_count;

    uint32_t turn;
    uint64_t turn_first_tick;
    uint8_t  turn_state;

    /*
     * How many turns have been taken back. Counted rather than derived, because
     * the log records what was DECLARED and a rollback is not a declaration --
     * there is nothing in the log to count afterwards.
     *
     * It is a statistic a session tells about itself at the end. See issue 1001.
     */
    uint32_t rollbacks;

    /*
     * The rules layer, or NULL. Held as a void pointer because 073-rules.h
     * includes this file -- a forward declaration would be cleaner and C does
     * not offer one that survives the cycle.
     *
     * Set with session_attach_rules, which takes the real type.
     */
    void *rules;

    /*
     * How many beats a window stays open. ONE IS A REAL CONFIGURATION, not a
     * degenerate one -- it is continuous play, and it must run through exactly
     * the same code as any other window rather than down a special path.
     */
    uint32_t window_ticks;
};

/*
 * Start a session over a world. The world is borrowed and the caller keeps it.
 * `ring_depth` is how many turns can be taken back.
 * Returns 1 on success, 0 if memory could not be found.
 */
int session_start(struct session *s,
                  struct world *world,
                  struct pool *pool,
                  uint64_t seed,
                  uint32_t ring_depth,
                  uint32_t window_ticks);

void session_release(struct session *s);

/*
 * Give the session per-viewer fog. Takes ownership of nothing -- the caller
 * keeps the array -- but the ring will snapshot and restore it.
 */
void session_attach_fogs(struct session *s, struct fog *fogs, uint32_t count);

/*
 * Give the session a ruleset. Gate 6 of the gauntlet runs between checking a
 * command and performing it, and pass 5 of the tick calls on_tick.
 *
 * Takes a `struct ruleset *`. Untyped here only because of the include cycle.
 */
void session_attach_rules(struct session *s, void *rules);

/*
 * Give the session a sprite library, so that the re-tier command has somewhere
 * to write.
 *
 * This is what makes judge-then-curate a TABLETOP idea rather than a gallery
 * one: without a library reachable from a live session, changing a sprite's tier
 * means stopping play and opening another program, and nobody does that in the
 * middle of a fight.
 *
 * Borrowed. The session does not own it and does not release it.
 */
void session_attach_sprites(struct session *s, void *sprites);

/*
 * The sentence the ruleset gave for the last refusal, or an empty string. Gate 6
 * is the only gate whose sentence the server does not write.
 */
const char *session_last_rules_refusal(const struct session *s);

/*
 * Offer a command. It is recorded first, then run through the gauntlet, so that
 * a refusal is in the log with its reason rather than being absent.
 * Returns the refusal reason, or REFUSED_NOT_AT_ALL.
 */
uint16_t session_command(struct session *s, uint16_t verb, uint32_t subject,
                         int32_t ax, int32_t ay);

/*
 * The same, from a particular participant. A viewer of 0 means the scripted
 * driver -- inside the process, with no seat at the table, and allowed
 * everything. Nothing arriving on a socket can be viewer 0, because a viewer
 * index comes from the port the bytes arrived on.
 */
uint16_t session_command_from(struct session *s, uint32_t viewer,
                              uint16_t verb, uint32_t subject,
                              int32_t ax, int32_t ay);

/* Advance one beat, closing and reopening the window when it is due. */
void session_tick(struct session *s);

/*
 * Take a turn back.
 *
 * ROLLBACK_REDECLARE restores the head and discards that turn's commands, so
 * everybody decides again.
 *
 * ROLLBACK_RETCON restores the head, keeps the commands, and replays them
 * forward -- so that a rewritten one takes effect and everything after it
 * follows.
 *
 * Returns 1 on success, 0 if that turn is no longer in the ring, which is a real
 * answer rather than a failure: the ring is finite and a session is long.
 */
int session_rollback(struct session *s, uint32_t turn, uint8_t mode);

/* Whether a turn is still far back enough to be reachable. */
int session_can_roll_back_to(const struct session *s, uint32_t turn);

/*
 * Why not, as a sentence. Empty when it can be.
 *
 * Two reasons: the turn fell out of the ring, or its sheets could not be copied
 * -- and the second one names which sheet and where. "That turn cannot be taken
 * back" is not something anybody can act on; "the goblin at sheet 3 holds a
 * function at .attack" is.
 */
const char *session_why_not_rollbackable(const struct session *s, uint32_t turn);

/* How deep the ring is, and how many turns it currently holds. */
uint32_t session_ring_depth(const struct session *s);
uint32_t session_ring_held(const struct session *s);

/* Roughly how much memory the ring costs, for a demo that reports it. */
uint64_t session_ring_bytes(const struct session *s);

#endif
