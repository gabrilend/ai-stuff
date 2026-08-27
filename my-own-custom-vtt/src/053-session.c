/*
 * 053-session.c -- the window, the ring of heads, and the replay forward.
 *
 * Interface and reasoning are in 053-session.h.
 *
 * The ring keeps one full copy of everything per turn. A world is a few hundred
 * kilobytes, so twenty turns of history is a few megabytes -- nothing. The
 * alternative, one snapshot every few turns plus replaying forward from it,
 * trades that memory for a delay a person would feel on a deep rollback. Keep
 * the ring and pay the memory; if a world ever grows enough for that to hurt,
 * the hybrid is there.
 */

#include "053-session.h"
#include "073-rules.h"
#include "070-scope.h"

#include <stdlib.h>
#include <string.h>

/* {{{ static int state_init */
static int state_init(struct turn_state *state, const struct world *like)
{
    memset(state, 0, sizeof(struct turn_state));

    /*
     * Sized to the world it will hold copies of. The blocks grow if they must,
     * but starting at the right size means a snapshot mid-session is a memcpy
     * rather than a memcpy preceded by an allocation.
     */
    if (!world_init(&state->world,
                    like->things.count + 8,
                    like->walls.count + 8,
                    like->regions.count + 4,
                    like->vertices.count + 8,
                    like->lights.count + 4,
                    like->strings.capacity)) {
        return 0;
    }

    return 1;
}
/* }}} */

/* {{{ static void state_release */
static void state_release(struct turn_state *state)
{
    world_release(&state->world);
    free(state->orders);

    if (state->fogs != NULL) {
        uint32_t i;
        for (i = 0; i < state->fog_count; i++) {
            fog_release(&state->fogs[i]);
        }
        free(state->fogs);
    }

    memset(state, 0, sizeof(struct turn_state));
}
/* }}} */

/* {{{ int session_start */
int session_start(struct session *s,
                  struct world *world,
                  struct pool *pool,
                  uint64_t seed,
                  uint32_t ring_depth,
                  uint32_t beats_between_checkpoints)
{
    uint32_t i;

    memset(s, 0, sizeof(struct session));

    s->world = world;
    s->pool = pool;

    /*
     * A window of one beat is continuous play, and it is a real configuration
     * rather than a degenerate one. Zero is not, so it is corrected to one --
     * a window of no beats would close before anybody could say anything.
     */
    s->beats_between_checkpoints = (beats_between_checkpoints == 0) ? 1 : beats_between_checkpoints;

    if (!sim_init(&s->sim, world, pool, seed)) {
        return 0;
    }

    if (!log_init(&s->log, 256)) {
        return 0;
    }

    if (ring_depth == 0) {
        ring_depth = 1;
    }

    s->ring.slots = calloc((size_t)ring_depth, sizeof(struct turn_state));
    if (s->ring.slots == NULL) {
        return 0;
    }
    s->ring.depth = ring_depth;

    for (i = 0; i < ring_depth; i++) {
        if (!state_init(&s->ring.slots[i], world)) {
            return 0;
        }
    }

    s->turn = 0;
    s->turn_first_tick = world->tick;
    s->turn_state = TURN_OPEN;

    log_begin_turn(&s->log, 0);

    return 1;
}
/* }}} */

/* {{{ void session_release */
void session_release(struct session *s)
{
    uint32_t i;

    for (i = 0; i < s->ring.depth; i++) {
        state_release(&s->ring.slots[i]);
    }
    free(s->ring.slots);

    log_release(&s->log);
    sim_release(&s->sim);

    free(s->told_about);

    memset(s, 0, sizeof(struct session));
}
/* }}} */

/* {{{ void session_attach_fogs */
void session_attach_fogs(struct session *s, struct fog *fogs, uint32_t count)
{
    s->fogs = fogs;
    s->fog_count = count;
}
/* }}} */

/* {{{ static int state_capture */
static int state_capture(struct session *s, struct turn_state *state)
{
    uint32_t i;

    state->turn = s->turn;
    state->tick = s->sim.tick;
    state->log_position = s->log.count;

    if (!world_copy(&state->world, s->world)) {
        return 0;
    }

    streams_copy(&state->streams, &s->sim.streams);

    /*
     * Standing orders are part of the state. A body walking toward a destination
     * is mid-decision, and a rollback that restored where it was standing but
     * not where it was going would have it wander off somewhere nobody chose.
     */
    if (state->order_count < s->sim.capacity) {
        struct order *moved = realloc(state->orders,
                                      (size_t)s->sim.capacity * sizeof(struct order));
        if (moved == NULL) {
            return 0;
        }
        state->orders = moved;
        state->order_count = s->sim.capacity;
    }
    memcpy(state->orders, s->sim.orders,
           (size_t)s->sim.capacity * sizeof(struct order));

    /*
     * And the fog. Rollback restores it with the world -- a full state restore --
     * because a fog left un-rolled holds a place reached in a turn that never
     * happened, and contradicts the world every time anybody walks there again.
     *
     * The cost is not pretended away: the person still remembers the corridor.
     * Their map closes over a room they can describe out loud. You cannot restore
     * ignorance; the program's job is to put the board back.
     */
    if (s->fog_count > 0) {
        if (state->fog_count != s->fog_count) {
            if (state->fogs != NULL) {
                for (i = 0; i < state->fog_count; i++) {
                    fog_release(&state->fogs[i]);
                }
                free(state->fogs);
            }

            state->fogs = calloc((size_t)s->fog_count, sizeof(struct fog));
            if (state->fogs == NULL) {
                state->fog_count = 0;
                return 0;
            }

            for (i = 0; i < s->fog_count; i++) {
                if (!fog_init(&state->fogs[i], s->world, s->fogs[i].cell_size)) {
                    return 0;
                }
            }

            state->fog_count = s->fog_count;
        }

        for (i = 0; i < s->fog_count; i++) {
            if (!fog_copy(&state->fogs[i], &s->fogs[i])) {
                return 0;
            }
        }
    }

    /*
     * And the ruleset's sheets, which are not flat bytes and so need a copy of
     * their own kind. See issue 703, reopened to close what was open question
     * 14.1 -- the largest known hole in the project for four phases.
     *
     * A failure here does NOT fail the capture. Play carries on; that one turn
     * simply cannot be taken back, and it says why. Failing the capture would
     * stop an evening over a line in somebody's homebrew, which is the same
     * argument that made an abandoned rule hook fail open.
     */
    state->sheets_copied = 1;
    state->sheet_trouble[0] = '\0';

    if (s->rules != NULL) {
        const char *why = "";

        if (!rules_snapshot_sheets((struct ruleset *)s->rules, s->turn, &why)) {
            state->sheets_copied = 0;
            snprintf(state->sheet_trouble, sizeof(state->sheet_trouble),
                     "%.240s", why);
        }
    }

    state->used = 1;

    return 1;
}
/* }}} */

/* {{{ static int state_restore */
static int state_restore(struct session *s, const struct turn_state *state)
{
    uint32_t i;

    if (!world_copy(s->world, &state->world)) {
        return 0;
    }

    streams_copy(&s->sim.streams, &state->streams);

    if (!sim_fit_to_world(&s->sim)) {
        return 0;
    }

    {
        uint32_t n = (state->order_count < s->sim.capacity)
                   ? state->order_count : s->sim.capacity;
        memcpy(s->sim.orders, state->orders, (size_t)n * sizeof(struct order));
    }

    for (i = 0; i < s->fog_count && i < state->fog_count; i++) {
        fog_copy(&s->fogs[i], &state->fogs[i]);
    }

    s->sim.tick = state->tick;
    s->world->tick = state->tick;
    s->turn = state->turn;
    s->turn_first_tick = state->tick;

    return 1;
}
/* }}} */

/* {{{ static void begin_turn */
static void begin_turn(struct session *s, uint32_t turn)
{
    struct turn_state *slot = &s->ring.slots[s->ring.next];

    s->turn = turn;
    s->turn_first_tick = s->sim.tick;
    s->turn_state = TURN_OPEN;

    log_begin_turn(&s->log, turn);

    /*
     * The head snapshot is taken when a window OPENS, not when it closes. What a
     * rollback wants is the state before anybody said anything.
     */
    /*
     * The slot about to be overwritten held a turn's sheets. Told to let them
     * go, because otherwise the snapshots table grows for the length of the
     * session and holds every turn ever played -- a leak that only appears on a
     * long evening.
     */
    if (s->rules != NULL && slot->used) {
        rules_forget_sheet_snapshot((struct ruleset *)s->rules, slot->turn);
    }

    state_capture(s, slot);

    s->ring.next = (s->ring.next + 1) % s->ring.depth;
}
/* }}} */

/* {{{ void session_attach_sprites */
void session_attach_sprites(struct session *s, void *sprites)
{
    /* Handed straight down to the simulation, because that is where the command
     * handlers live. The session is the thing that OWNS the arrangement; the sim
     * is the thing that uses it. */
    sim_attach_sprites(&s->sim, sprites);
}
/* }}} */

/* {{{ void session_attach_rules */
void session_attach_rules(struct session *s, void *rules)
{
    s->rules = rules;

    if (rules != NULL) {
        ((struct ruleset *)rules)->sim = &s->sim;
    }
}
/* }}} */

/* {{{ const char *session_last_rules_refusal */
const char *session_last_rules_refusal(const struct session *s)
{
    if (s->rules == NULL) {
        return "";
    }

    return ((const struct ruleset *)s->rules)->last_refusal;
}
/* }}} */

/* {{{ uint16_t session_command */
uint16_t session_command(struct session *s, uint16_t verb, uint32_t subject,
                         int32_t ax, int32_t ay)
{
    return session_command_from(s, 0, verb, subject, ax, ay);
}
/* }}} */

/* {{{ uint16_t session_command_from */
uint16_t session_command_from(struct session *s, uint32_t viewer,
                              uint16_t verb, uint32_t subject,
                              int32_t ax, int32_t ay)
{
    struct log_entry entry;
    uint32_t index;
    uint16_t refusal;

    memset(&entry, 0, sizeof(entry));
    entry.tick = s->sim.tick;
    entry.turn = s->turn;
    entry.viewer = viewer;
    entry.verb = verb;
    entry.subject = subject;
    entry.ax = ax;
    entry.ay = ay;

    /*
     * Recorded BEFORE the gauntlet, so that a refusal is in the log with its
     * reason. A log that only holds what succeeded cannot answer "why did
     * nothing happen when I pressed that".
     */
    index = log_record(&s->log, &entry);

    /*
     * Gates 1 through 5, then the ruleset, then the change. In that order,
     * because a ruleset asked to veto something that has already happened is not
     * a veto -- and because a refusal must leave the world exactly as it was.
     */
    refusal = command_check(&s->sim, &entry);

    /*
     * ACTING ON SOMETHING YOU DO NOT COMMAND takes a different path, because it
     * takes a different gate and a different hook. It is performed here rather
     * than in the verb table for the same reason gate 6 runs here: this is the
     * only place that has both the ruleset and the record of what this viewer
     * was told about.
     *
     * The gate is SIGHT, and it is the same decision the outbound path already
     * made -- remembered, not recomputed. Two answers to "can this person see
     * that" is how a permission model develops a hole nobody can find.
     */
    /*
     * REMOVING SOMEBODY. Queued rather than done: the session owns the decision,
     * which just went through the gauntlet, and the server owns the sockets.
     *
     * Their scopes are unheld here and now, because that is world state and the
     * session owns the world. Their bodies are not touched -- removing a person
     * is not removing a character.
     */
    if (refusal == REFUSED_NOT_AT_ALL && verb == VERB_EVICT) {
        if (s->evicting_count >= SESSION_MAX_EVICTIONS) {
            refusal = REFUSED_TOO_MANY_AT_ONCE;
        } else {
            scope_unhold_all(s->world, subject);

            s->evicting[s->evicting_count] = subject;
            s->evicting_count++;

            /* And whatever they had been told about is forgotten, so a seat
             * index reused by somebody else does not inherit their sight. */
            session_forget_what_was_told(s, subject);
        }

        if (refusal != REFUSED_NOT_AT_ALL) {
            log_mark_refused(&s->log, index, refusal);
        }

        return refusal;
    }

    if (refusal == REFUSED_NOT_AT_ALL && verb == VERB_INTERACT) {
        /*
         * Viewer 0 is the scripted driver, inside the process, with no seat at
         * the table and no update ever built for it. It is allowed, the same way
         * it is allowed everything else -- and nothing arriving on a socket can
         * be viewer 0, because a viewer index comes from the port the bytes
         * arrived on.
         */
        if (viewer != 0 && !session_was_told(s, viewer, subject)) {
            refusal = REFUSED_CANNOT_SEE_IT;
        } else if (s->rules == NULL) {
            refusal = REFUSED_NO_RULES_FOR_THAT;
        } else {
            struct ruleset *rules = (struct ruleset *)s->rules;
            uint32_t actor = 0;
            uint32_t eyes[1];

            /* Who did it, as a body rather than a seat, because a ruleset
             * reasons about creatures and not about sockets. */
            if (scope_eyes_of_viewer(s->world, viewer, eyes, 1) > 0) {
                actor = eyes[0];
            }

            if (!rules_on_interact(rules, viewer, actor, subject,
                                   (uint32_t)ax)) {
                refusal = REFUSED_BY_THE_RULES;
            }
        }

        if (refusal != REFUSED_NOT_AT_ALL) {
            log_mark_refused(&s->log, index, refusal);
        }

        return refusal;
    }

    if (refusal == REFUSED_NOT_AT_ALL && s->rules != NULL) {
        refusal = rules_on_command((struct ruleset *)s->rules, viewer, &entry);
    }

    if (refusal == REFUSED_NOT_AT_ALL) {
        refusal = command_perform(&s->sim, &entry);
    }

    if (refusal != REFUSED_NOT_AT_ALL) {
        log_mark_refused(&s->log, index, refusal);
    }

    return refusal;
}
/* }}} */

/* {{{ void session_tick */
void session_tick(struct session *s)
{
    sim_tick(&s->sim);

    /*
     * Pass 5 of the tick table, which has been an empty row since phase 3. And
     * the crossings pass 4 collected, delivered in index order on one thread --
     * a ruleset called from three threads at once could not be deterministic.
     */
    if (s->rules != NULL) {
        struct ruleset *rules = s->rules;
        const struct crossing *crossings;
        uint32_t count = 0;
        uint32_t i;

        crossings = sim_crossings(&s->sim, &count);

        for (i = 0; i < count; i++) {
            rules_on_region_enter(rules, crossings[i].thing,
                                  crossings[i].left, crossings[i].entered);
        }

        rules_on_tick(rules);
    }

    /*
     * A checkpoint, and the next turn opens on the same beat.
     *
     * NOTHING WAITS HERE. Commands were accepted on every beat above and applied
     * on the beat they arrived; this is only where the world is copied aside so
     * that somebody can come back to it. Play runs continuously and a turn is a
     * place you can go back to.
     *
     * That is worth stating in the code because the field used to be called a
     * window, and a window is a thing you wait in -- which made a perfectly
     * ordinary interval sound like a rule about how the table plays.
     */
    if (s->sim.tick - s->turn_first_tick >= s->beats_between_checkpoints) {
        begin_turn(s, s->turn + 1);
    }
}
/* }}} */

/* {{{ static struct turn_state *find_turn */
static struct turn_state *find_turn(struct session *s, uint32_t turn)
{
    uint32_t i;

    for (i = 0; i < s->ring.depth; i++) {
        if (s->ring.slots[i].used && s->ring.slots[i].turn == turn) {
            return &s->ring.slots[i];
        }
    }

    return NULL;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * What each viewer was told about
 *
 * One bit per viewer per thing, written by the outbound path and read by the
 * gate on acting-on-something-you-do-not-command.
 *
 * THE SAME DECISION, NOT A SECOND ONE. Working out visibility again in the
 * command path would be a second answer to "can this person see that", and two
 * answers to a permission question is how a model develops a hole nobody can
 * find. This is the first answer, remembered.
 * ------------------------------------------------------------------------- */

/* {{{ static int fit_the_told_table */
static int fit_the_told_table(struct session *s, uint32_t viewer, uint32_t thing)
{
    uint32_t viewers = (viewer + 1u > s->told_viewers) ? viewer + 1u : s->told_viewers;
    uint32_t things = world_thing_count(s->world);

    if (thing + 1u > things) {
        things = thing + 1u;
    }

    if (viewers == s->told_viewers && things <= s->told_things
        && s->told_about != NULL) {
        return 1;
    }

    {
        uint8_t *grown = calloc((size_t)viewers * (size_t)things, 1);
        uint32_t v;

        if (grown == NULL) {
            return 0;
        }

        /* Carried over rather than cleared, because growing the table happens
         * when somebody joins and the people already at the table have not
         * stopped being able to see anything. */
        for (v = 0; v < s->told_viewers && s->told_about != NULL; v++) {
            memcpy(grown + (size_t)v * things,
                   s->told_about + (size_t)v * s->told_things,
                   (size_t)s->told_things);
        }

        free(s->told_about);
        s->told_about = grown;
        s->told_viewers = viewers;
        s->told_things = things;
    }

    return 1;
}
/* }}} */

/* {{{ void session_forget_what_was_told */
void session_forget_what_was_told(struct session *s, uint32_t viewer)
{
    if (s->told_about == NULL || viewer >= s->told_viewers) {
        return;
    }

    memset(s->told_about + (size_t)viewer * s->told_things, 0,
           (size_t)s->told_things);
}
/* }}} */

/* {{{ void session_note_told */
void session_note_told(struct session *s, uint32_t viewer, uint32_t thing)
{
    if (!fit_the_told_table(s, viewer, thing)) {
        return;
    }

    s->told_about[(size_t)viewer * s->told_things + thing] = 1;
}
/* }}} */

/* {{{ int session_was_told */
int session_was_told(const struct session *s, uint32_t viewer, uint32_t thing)
{
    if (s->told_about == NULL || viewer >= s->told_viewers
        || thing >= s->told_things) {
        return 0;
    }

    return s->told_about[(size_t)viewer * s->told_things + thing] != 0;
}
/* }}} */

/* {{{ uint32_t session_take_evictions */
uint32_t session_take_evictions(struct session *s, uint32_t *into,
                                uint32_t capacity)
{
    uint32_t found = s->evicting_count;
    uint32_t i;

    for (i = 0; i < found && i < capacity; i++) {
        into[i] = s->evicting[i];
    }

    s->evicting_count = 0;

    /* The TRUE count, which may be more than fitted. A caller given fewer than
     * there were must be able to say so rather than silently leaving somebody
     * at a table they were removed from. */
    return found;
}
/* }}} */

/* {{{ uint32_t session_earliest_turn_touched_by */
uint32_t session_earliest_turn_touched_by(const struct session *s, uint32_t viewer)
{
    uint32_t earliest = s->turn;
    uint32_t i;

    for (i = 0; i < s->log.count; i++) {
        if (s->log.entries[i].viewer == viewer && s->log.entries[i].turn < earliest) {
            earliest = s->log.entries[i].turn;
        }
    }

    return earliest;
}
/* }}} */

/* {{{ int session_expunge */
int session_expunge(struct session *s, uint32_t viewer, uint32_t turn)
{
    struct turn_state *head = find_turn(s, turn);
    uint32_t log_end;
    uint32_t entry;
    uint64_t replay_to;

    if (head == NULL || !head->sheets_copied) {
        return 0;
    }

    log_end = s->log.count;
    replay_to = s->sim.tick;

    if (!state_restore(s, head)) {
        return 0;
    }

    if (s->rules != NULL) {
        const char *why = "";

        if (!rules_restore_sheets((struct ruleset *)s->rules, turn, &why)) {
            return 0;
        }
    }

    s->rollbacks++;

    /*
     * The retcon, with one condition inside it.
     *
     * That is the whole of the difference, and it is possible only because the
     * log records WHO issued every entry. Nothing had to be added to make this
     * work, which is a sign the log was recorded at the right grain.
     */
    entry = head->log_position;

    while (s->sim.tick < replay_to) {
        while (entry < log_end && s->log.entries[entry].tick <= s->sim.tick) {
            if (s->log.entries[entry].viewer == viewer) {
                /*
                 * Skipped, and MARKED rather than deleted. A log that quietly
                 * omits the parts somebody regretted is not a log, and the
                 * refusal reason says which of the two kinds of not-happening
                 * this was.
                 */
                log_mark_refused(&s->log, entry, REFUSED_NOT_YOURS);
            } else {
                uint16_t refusal = command_apply(&s->sim, &s->log.entries[entry]);

                log_mark_refused(&s->log, entry, refusal);
            }

            entry++;
        }

        sim_tick(&s->sim);

        if (s->sim.tick - s->turn_first_tick >= s->beats_between_checkpoints) {
            /* Turn boundaries replayed without re-snapshotting, the same as an
             * ordinary retcon, and for the same reason. */
            s->turn++;
            s->turn_first_tick = s->sim.tick;
        }
    }

    while (entry < log_end) {
        if (s->log.entries[entry].viewer != viewer) {
            command_apply(&s->sim, &s->log.entries[entry]);
        }
        entry++;
    }

    return 1;
}
/* }}} */

/* {{{ int session_can_roll_back_to */
int session_can_roll_back_to(const struct session *s, uint32_t turn)
{
    uint32_t i;

    for (i = 0; i < s->ring.depth; i++) {
        if (s->ring.slots[i].used && s->ring.slots[i].turn == turn) {
            /*
             * Two reasons a turn is not rollbackable, and this is the second
             * one. The first is that it fell out of the ring. The second is that
             * its sheets could not be copied -- and both must be answered
             * BEFORE anybody restores anything, because a half-restore is worse
             * than a refusal.
             */
            return s->ring.slots[i].sheets_copied ? 1 : 0;
        }
    }

    return 0;
}
/* }}} */

/* {{{ const char *session_why_not_rollbackable */
const char *session_why_not_rollbackable(const struct session *s, uint32_t turn)
{
    uint32_t i;

    for (i = 0; i < s->ring.depth; i++) {
        if (s->ring.slots[i].used && s->ring.slots[i].turn == turn) {
            if (s->ring.slots[i].sheets_copied) {
                return "";
            }
            return s->ring.slots[i].sheet_trouble;
        }
    }

    return "that turn has fallen out of the ring";
}
/* }}} */

/* {{{ int session_rollback */
int session_rollback(struct session *s, uint32_t turn, uint8_t mode)
{
    struct turn_state *head = find_turn(s, turn);
    uint32_t log_end;
    uint32_t entry;
    uint64_t replay_to;

    /*
     * The ring is finite and a session is long, so a turn falling out of it is a
     * real answer rather than a failure. Reported rather than approximated:
     * restoring the nearest turn we still have would put the world somewhere
     * nobody asked for.
     */
    if (head == NULL) {
        return 0;
    }

    log_end = s->log.count;
    replay_to = s->sim.tick;

    /*
     * A turn whose sheets could not be copied is not rollbackable. Refused
     * before anything is restored, so the world is left exactly where it was --
     * a half-restore is the failure this whole path exists to avoid.
     */
    if (!head->sheets_copied) {
        return 0;
    }

    if (!state_restore(s, head)) {
        return 0;
    }

    if (s->rules != NULL) {
        const char *why = "";

        if (!rules_restore_sheets((struct ruleset *)s->rules, turn, &why)) {
            /*
             * The world is already back. This cannot be undone and is not
             * pretended away: the caller gets a 0, which it must read as "the
             * geometry moved and the numbers did not", and the ruleset's own
             * last_error says which sheet.
             */
            return 0;
        }
    }

    /*
     * Counted here rather than at the top, so a rollback that could not restore
     * is not counted as one that did. See issue 1001 -- this is a statistic the
     * session tells about itself at the end.
     */
    s->rollbacks++;

    if (mode == ROLLBACK_REDECLARE) {
        /*
         * Discard what was declared. The window reopens and everybody decides
         * again -- for a dropped connection, or a misread situation.
         */
        s->log.count = head->log_position;
        s->turn_state = TURN_OPEN;
        return 1;
    }

    /*
     * A retcon. The commands are kept, one of them may have been rewritten, and
     * everything is replayed forward so that the correction propagates.
     *
     * This only works because the log is decoded and indexed rather than a stream
     * of bytes, and because the tick lands in the same place every time.
     */
    entry = head->log_position;

    while (s->sim.tick < replay_to) {
        while (entry < log_end && s->log.entries[entry].tick <= s->sim.tick) {
            uint16_t refusal = command_apply(&s->sim, &s->log.entries[entry]);
            log_mark_refused(&s->log, entry, refusal);
            entry++;
        }

        sim_tick(&s->sim);

        if (s->sim.tick - s->turn_first_tick >= s->beats_between_checkpoints) {
            /*
             * Turn boundaries are replayed too, but WITHOUT re-snapshotting --
             * the ring already holds these heads, and overwriting them would
             * destroy the very history a second rollback would need.
             */
            s->turn++;
            s->turn_first_tick = s->sim.tick;
        }
    }

    /* Anything left over was declared after the point we replayed to. */
    while (entry < log_end) {
        command_apply(&s->sim, &s->log.entries[entry]);
        entry++;
    }

    return 1;
}
/* }}} */

/* {{{ uint32_t session_ring_depth */
uint32_t session_ring_depth(const struct session *s)
{
    return s->ring.depth;
}
/* }}} */

/* {{{ uint32_t session_ring_held */
uint32_t session_ring_held(const struct session *s)
{
    uint32_t held = 0;
    uint32_t i;

    for (i = 0; i < s->ring.depth; i++) {
        if (s->ring.slots[i].used) {
            held++;
        }
    }

    return held;
}
/* }}} */

/* {{{ uint64_t session_ring_bytes */
uint64_t session_ring_bytes(const struct session *s)
{
    uint64_t per_slot = 0;
    uint32_t i;

    if (s->ring.depth == 0) {
        return 0;
    }

    {
        const struct turn_state *slot = &s->ring.slots[0];

        per_slot += (uint64_t)block_bytes_used(&slot->world.things);
        per_slot += (uint64_t)block_bytes_used(&slot->world.walls);
        per_slot += (uint64_t)block_bytes_used(&slot->world.regions);
        per_slot += (uint64_t)block_bytes_used(&slot->world.vertices);
        per_slot += (uint64_t)block_bytes_used(&slot->world.lights);
        per_slot += slot->world.strings.used;
        per_slot += sizeof(struct stream_registry);
        per_slot += (uint64_t)slot->order_count * sizeof(struct order);

        for (i = 0; i < slot->fog_count; i++) {
            per_slot += slot->fogs[i].byte_count;
        }
    }

    return per_slot * (uint64_t)s->ring.depth;
}
/* }}} */
