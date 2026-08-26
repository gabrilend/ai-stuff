/*
 * 051-commandlog.c -- the record, and the table that turns it into changes.
 *
 * Interface and reasoning are in 051-commandlog.h.
 */

#include "051-commandlog.h"

#include "085-sprite-pool.h"
#include "070-scope.h"

#include <stdlib.h>
#include <string.h>

/* {{{ int log_init */
int log_init(struct command_log *log, uint32_t capacity)
{
    memset(log, 0, sizeof(struct command_log));

    if (capacity < 16) {
        capacity = 16;
    }

    log->entries = calloc((size_t)capacity, sizeof(struct log_entry));
    if (log->entries == NULL) {
        return 0;
    }
    log->capacity = capacity;

    log->turn_start = calloc(64, sizeof(uint32_t));
    if (log->turn_start == NULL) {
        free(log->entries);
        log->entries = NULL;
        return 0;
    }
    log->turn_capacity = 64;

    return 1;
}
/* }}} */

/* {{{ void log_release */
void log_release(struct command_log *log)
{
    free(log->entries);
    free(log->turn_start);
    memset(log, 0, sizeof(struct command_log));
}
/* }}} */

/* {{{ static int grow_entries */
static int grow_entries(struct command_log *log)
{
    uint32_t wanted = log->capacity * 2;
    struct log_entry *moved = realloc(log->entries,
                                      (size_t)wanted * sizeof(struct log_entry));

    if (moved == NULL) {
        return 0;
    }

    log->entries = moved;
    log->capacity = wanted;

    return 1;
}
/* }}} */

/* {{{ int log_begin_turn */
int log_begin_turn(struct command_log *log, uint32_t turn)
{
    if (turn >= log->turn_capacity) {
        uint32_t wanted = log->turn_capacity * 2;
        uint32_t *moved;

        while (turn >= wanted) {
            wanted *= 2;
        }

        moved = realloc(log->turn_start, (size_t)wanted * sizeof(uint32_t));
        if (moved == NULL) {
            return 0;
        }

        memset(moved + log->turn_capacity, 0,
               (size_t)(wanted - log->turn_capacity) * sizeof(uint32_t));

        log->turn_start = moved;
        log->turn_capacity = wanted;
    }

    /*
     * Where this turn's commands begin. Recorded rather than searched for, so
     * that rolling back to a turn's head is a lookup and not a scan backwards
     * through hours of a session.
     */
    log->turn_start[turn] = log->count;

    if (turn >= log->turn_count) {
        log->turn_count = turn + 1;
    }

    return 1;
}
/* }}} */

/* {{{ uint32_t log_record */
uint32_t log_record(struct command_log *log, const struct log_entry *entry)
{
    uint32_t index;

    if (log->count >= log->capacity && !grow_entries(log)) {
        return log->count;
    }

    index = log->count;
    log->entries[index] = *entry;
    log->count++;

    return index;
}
/* }}} */

/* {{{ void log_mark_refused */
void log_mark_refused(struct command_log *log, uint32_t index, uint16_t refusal)
{
    if (index >= log->count) {
        return;
    }

    /*
     * The command stays in the log. A record that omits what somebody tried and
     * was told they could not do cannot answer "why did nothing happen when I
     * pressed that", which is the most direct evidence there is about where an
     * interface confuses people.
     */
    log->entries[index].refusal = refusal;
}
/* }}} */

/* {{{ uint32_t log_turn_first */
uint32_t log_turn_first(const struct command_log *log, uint32_t turn)
{
    if (turn >= log->turn_count) {
        return log->count;
    }

    return log->turn_start[turn];
}
/* }}} */

/* {{{ uint32_t log_turn_count */
uint32_t log_turn_count(const struct command_log *log, uint32_t turn)
{
    uint32_t first;
    uint32_t next;

    if (turn >= log->turn_count) {
        return 0;
    }

    first = log->turn_start[turn];
    next = (turn + 1 < log->turn_count) ? log->turn_start[turn + 1] : log->count;

    return (next > first) ? (next - first) : 0;
}
/* }}} */

/* {{{ void log_rewrite */
void log_rewrite(struct command_log *log, uint32_t index, const struct log_entry *entry)
{
    if (index >= log->count) {
        return;
    }

    /*
     * A retcon. The GM ruled wrongly and wants the turn to have gone differently,
     * with everything downstream following from the correction.
     *
     * Only possible because this log is decoded and indexed rather than a stream
     * of bytes -- and dangerous for exactly the same reason, because it changes
     * what somebody did without asking them.
     */
    log->entries[index] = *entry;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * The dispatch table
 *
 * One row per verb. Adding a command is adding a row -- a name, and what it does.
 * ------------------------------------------------------------------------- */

/* {{{ static uint16_t apply_drive */
static uint16_t apply_drive(struct sim *s, const struct log_entry *e)
{
    /*
     * ax carries the direction. The angle space is sixteen bits wide, so every
     * value that fits is a legal direction -- there is no such thing as an
     * out-of-range angle, and nothing here has to check for one.
     */
    sim_drive(s, e->subject, (wangle)(uint32_t)e->ax, (wcoord)e->ay);
    return REFUSED_NOT_AT_ALL;
}
/* }}} */

/* {{{ static uint16_t apply_order_move */
static uint16_t apply_order_move(struct sim *s, const struct log_entry *e)
{
    /*
     * Speed is not carried per command; a body walks at the pace it was last
     * given. One metre a beat if it has never been told otherwise, which is a
     * documented default for an absent field rather than a fallback for a
     * malformed one.
     */
    wcoord speed = s->orders[e->subject].speed;

    if (speed == 0) {
        speed = WC_ONE;
    }

    sim_order_move(s, e->subject, (wcoord)e->ax, (wcoord)e->ay, speed);
    return REFUSED_NOT_AT_ALL;
}
/* }}} */

/* {{{ static uint16_t apply_order_face */
static uint16_t apply_order_face(struct sim *s, const struct log_entry *e)
{
    const struct thing *t = world_thing_const(s->world, e->subject);
    wangle direction;

    /*
     * Looking at where you already are has no direction. Answered here rather
     * than being handed to fx_angle, which would return zero for a question it
     * was not asked -- and a body silently snapping to due east is the kind of
     * wrong that nobody reports and everybody notices.
     */
    if (t->x == (wcoord)e->ax && t->y == (wcoord)e->ay) {
        return REFUSED_NOT_AT_ALL;
    }

    direction = fx_angle((wcoord)e->ax - t->x, (wcoord)e->ay - t->y);
    sim_order_face(s, e->subject, direction);

    return REFUSED_NOT_AT_ALL;
}
/* }}} */

/* {{{ static uint16_t apply_give_scope */
static uint16_t apply_give_scope(struct sim *s, const struct log_entry *e)
{
    /*
     * A GM hands the tavern to somebody who has just arrived. The whole
     * mechanism is one field changing -- and because a scope is world state, the
     * handover is snapshotted, rolled back, and hashed like anything else.
     *
     * `subject` is the scope, and `ax` is the viewer receiving it. A viewer of 0
     * unholds it, which is a legal and normal thing: the forest exists whether
     * anybody is playing it tonight.
     */
    uint32_t scope = (uint32_t)e->ax;
    uint32_t receiver = (uint32_t)e->ay;

    if (scope == 0 || scope >= world_scope_count(s->world)) {
        return REFUSED_NO_SUCH_SCOPE;
    }

    /*
     * Standing orders belong to the BODIES, not to the scope, so they survive a
     * handover -- the new commander inherits six goblins already walking
     * somewhere for reasons nobody told them.
     *
     * That is what falls out of doing nothing, and it is worth being honest that
     * it is a default rather than a decision. Open question 6.3.
     */
    world_scope(s->world, scope)->viewer = receiver;

    return REFUSED_NOT_AT_ALL;
}
/* }}} */

/* {{{ static uint16_t apply_order_stop */
static uint16_t apply_order_stop(struct sim *s, const struct log_entry *e)
{
    sim_order_stop(s, e->subject);
    return REFUSED_NOT_AT_ALL;
}
/* }}} */

/*
 * {{{ static uint16_t apply_retier
 *
 * Say what somebody thought of a picture.
 *
 * NOTHING IN THE WORLD IS TOUCHED. Not a coordinate, not a flag, not a tick.
 * That is what lets this arrive in the middle of a turn without a replay
 * diverging or a world hash moving, and a test asserts exactly that.
 *
 * The library is borrowed by the simulation the way a ruleset is borrowed by the
 * session -- as an opaque pointer, because the tick has no business knowing what
 * a sprite is and the sprite pool has no business knowing what a tick is.
 */
static uint16_t apply_retier(struct sim *s, const struct log_entry *e)
{
    struct sprite_pool *library = (struct sprite_pool *)s->sprites;
    const struct thing *t = world_thing_const(s->world, e->subject);
    char category[SPRITE_NAME_MAX + 1];
    char who[RATER_NAME_MAX + 1];
    const char *bytes;
    uint32_t length = 0;
    uint32_t entry;

    /*
     * Strings in the pool are not null-terminated -- a length is one read where
     * a terminator is a scan, and a scan over bytes somebody else influenced is
     * a scan that can run off the end. So it is copied out with its length.
     */
    bytes = string_pool_read(&s->world->strings, t->sprite_category, &length);

    if (length > SPRITE_NAME_MAX) {
        length = SPRITE_NAME_MAX;
    }
    memcpy(category, bytes, length);
    category[length] = '\0';

    /*
     * WHO RATED IT IS A SEAT, NOT A DISPLAY NAME.
     *
     * A viewer has a name and this deliberately does not use it. That field is
     * marked display-only and never used to decide anything, everywhere it
     * appears -- and a rating in a library that outlives the session is exactly
     * the kind of durable record that must not be keyed on something somebody
     * can change between one evening and the next. Two people who both called
     * themselves "GM" would become one rater; one person who renamed themselves
     * would become two.
     *
     * Seat 0 is the scripted driver -- a test, or a demo -- which has no seat at
     * the table but is still somebody, and signs its work rather than leaving a
     * rating with no rater.
     */
    if (e->viewer == 0) {
        snprintf(who, sizeof(who), "%s", "the-table");
    } else {
        snprintf(who, sizeof(who), "seat-%u", (unsigned)e->viewer);
    }

    /*
     * Found or made. A picture nobody had entered in the library is entered now,
     * carrying its rating with it -- because the alternative is refusing to
     * record an opinion somebody actually held, on the grounds of bookkeeping.
     */
    entry = pool_add(library, category, t->sprite_seed, s->tick);
    if (entry == POOL_NOTHING) {
        return REFUSED_WEARS_NOTHING;
    }

    if (!pool_rate_by_person(library, entry, (uint8_t)e->ax, who, s->tick)) {
        return REFUSED_NOT_A_TIER;
    }

    return REFUSED_NOT_AT_ALL;
}
/* }}} */

typedef uint16_t (*verb_handler)(struct sim *, const struct log_entry *);

static const struct {
    const char  *name;
    verb_handler handle;
} verb_table[VERB_COUNT] = {
    { "none",       NULL },
    { "drive",      apply_drive },
    { "order-move", apply_order_move },
    { "order-face", apply_order_face },
    { "order-stop", apply_order_stop },
    { "give-scope", apply_give_scope },
    { "retier",     apply_retier }
};

/* {{{ uint16_t command_check */
uint16_t command_check(struct sim *s, const struct log_entry *entry)
{
    /*
     * The gauntlet, in the order the document gives: cheapest and most
     * fundamental first, so a malformed command fails on something simple.
     *
     * The scope and membership gates are missing because scopes do not exist
     * until phase 6. What is here is the shape they will slot into.
     */

    if (entry->verb == VERB_NONE || entry->verb >= VERB_COUNT) {
        return REFUSED_UNKNOWN_VERB;
    }

    /*
     * Handing a scope over is about a scope rather than a body, so it takes a
     * different gate: MAY_EDIT_WORLD, not membership. Checked before the subject
     * gates below, which would otherwise refuse it for having no body.
     *
     * Who may hand a scope over is not obvious -- a GM plausibly, the current
     * holder plausibly, both plausibly. MAY_EDIT_WORLD is the narrow answer.
     */
    if (entry->verb == VERB_GIVE_SCOPE) {
        if (entry->viewer != 0 &&
            !viewer_has_flag(s->world, entry->viewer, SCOPE_MAY_EDIT_WORLD)) {
            return REFUSED_MAY_NOT_EDIT;
        }

        return REFUSED_NOT_AT_ALL;
    }

    /*
     * Re-tiering is about a picture rather than about a body, but it names a
     * body, so it takes the ordinary subject gates below AND one of its own.
     *
     * WHO MAY, FOR NOW: whoever may edit the world. The narrow answer, matching
     * VERB_GIVE_SCOPE. There is no leak in letting a player re-tier a sprite
     * they can already see -- the tier is about the kind and they are looking at
     * one -- but a shared library any of six people can re-tier mid-session
     * without discussion is a different social object from one the GM curates.
     * Widening this later breaks nothing; narrowing it later would. Open
     * question 10.2.
     */
    if (entry->verb == VERB_RETIER) {
        if (entry->viewer != 0 &&
            !viewer_has_flag(s->world, entry->viewer, SCOPE_MAY_EDIT_WORLD)) {
            return REFUSED_MAY_NOT_EDIT;
        }

        /* Refused here rather than clamped, so a client with a ten-point scale
         * is told so instead of having its nine quietly become a five. */
        if (entry->ax < 1 || entry->ax > 5) {
            return REFUSED_NOT_A_TIER;
        }

        if (s->sprites == NULL) {
            return REFUSED_NO_LIBRARY;
        }
    }

    /*
     * A reference is the one kind of field that CAN be wrong. Every bit pattern
     * is a legal uint32_t and most of them point past the end of the things
     * array -- so this is refused, never clamped. Clamping an index would aim a
     * command at whichever body happened to be last.
     */
    if (entry->subject == 0) {
        return REFUSED_SUBJECT_IS_NOTHING;
    }

    if (entry->subject >= world_thing_count(s->world) ||
        entry->subject >= s->capacity) {
        return REFUSED_NO_SUCH_SUBJECT;
    }

    /*
     * GATE 4: is the subject inside a scope this viewer holds?
     *
     * A viewer of 0 is the scripted driver used by tests and by phase 3's demo,
     * which has no seat at the table and is allowed everything. That is a
     * deliberate hole and it is only reachable from inside the process -- nothing
     * arriving on a socket can carry viewer 0, because a viewer index comes from
     * the port the bytes arrived on.
     */
    if (entry->viewer != 0) {
        uint32_t scope = scope_of_viewer_containing(s->world, entry->viewer,
                                                    entry->subject);

        if (scope == 0) {
            return REFUSED_NOT_YOURS;
        }

        /*
         * GATE 5: does the verb suit the scope's style? Driving a body you can
         * only give orders to is a category error, and somebody whose keys do
         * nothing needs to be told that rather than left to suspect their
         * keyboard.
         */
        if (!scope_style_allows(s->world, scope, entry->verb)) {
            return REFUSED_WRONG_STYLE;
        }
    }

    /*
     * And it must be wearing a picture. A thing with no sprite has nothing for
     * anybody to have an opinion of, and recording a tier against the empty
     * category would put a row in the library that names nothing.
     */
    if (entry->verb == VERB_RETIER &&
        world_thing_const(s->world, entry->subject)->sprite_category == 0) {
        return REFUSED_WEARS_NOTHING;
    }

    /*
     * GATE 6, the ruleset, is run by the SESSION between checking and
     * performing -- because a ruleset asked to veto something that has already
     * happened is not a veto.
     */

    return REFUSED_NOT_AT_ALL;
}
/* }}} */

/* {{{ uint16_t command_perform */
uint16_t command_perform(struct sim *s, const struct log_entry *entry)
{
    if (entry->verb == VERB_NONE || entry->verb >= VERB_COUNT) {
        return REFUSED_UNKNOWN_VERB;
    }

    return verb_table[entry->verb].handle(s, entry);
}
/* }}} */

/* {{{ uint16_t command_apply */
uint16_t command_apply(struct sim *s, const struct log_entry *entry)
{
    uint16_t refusal = command_check(s, entry);

    if (refusal != REFUSED_NOT_AT_ALL) {
        return refusal;
    }

    return command_perform(s, entry);
}
/* }}} */

/* {{{ const char *refusal_sentence */
const char *refusal_sentence(uint16_t refusal)
{
    /*
     * A sentence a person can read, always. Never a number, never silence, never
     * a command that appears to work and quietly does not.
     *
     * This is not politeness -- nobody reads a rules screen, and a refusal is
     * where somebody finds out what the rules are at the moment they try.
     */
    switch (refusal) {
    case REFUSED_NOT_AT_ALL:
        return "accepted";
    case REFUSED_UNKNOWN_VERB:
        return "that is not a command this server understands";
    case REFUSED_NO_SUCH_SUBJECT:
        return "there is nothing here with that index";
    case REFUSED_SUBJECT_IS_NOTHING:
        return "nothing is not a thing you can give an order to";
    case REFUSED_NOT_YOURS:
        return "that is not yours to command";
    case REFUSED_WRONG_STYLE:
        return "that one takes orders rather than being driven, or the other way about";
    case REFUSED_MAY_NOT_EDIT:
        return "handing a scope over is an edit, and you may not edit the world";
    case REFUSED_NO_SUCH_SCOPE:
        return "there is no scope with that index";
    case REFUSED_NO_LIBRARY:
        return "there is no sprite library attached, so there is nowhere to"
               " record what you thought";
    case REFUSED_NOT_A_TIER:
        return "a tier is 1 to 5 on this scale, and yours is not one of them";
    case REFUSED_WEARS_NOTHING:
        return "that one is not wearing a picture, so there is nothing to rate";
    case REFUSED_BY_THE_RULES:
        /*
         * A placeholder. The real sentence came from the ruleset and lives in
         * its last_refusal -- this is what a caller gets if it forgets to ask.
         */
        return "the rules do not allow that";
    default:
        return "refused, for a reason nobody wrote down -- which is a bug";
    }
}
/* }}} */

/* {{{ const char *verb_name */
const char *verb_name(uint16_t verb)
{
    if (verb >= VERB_COUNT) {
        return "unknown";
    }

    return verb_table[verb].name;
}
/* }}} */

/* {{{ uint32_t log_refused_count */
uint32_t log_refused_count(const struct command_log *log)
{
    uint32_t total = 0;
    uint32_t i;

    for (i = 0; i < log->count; i++) {
        if (log->entries[i].refusal != REFUSED_NOT_AT_ALL) {
            total++;
        }
    }

    return total;
}
/* }}} */

/* {{{ void log_dump */
void log_dump(const struct command_log *log, FILE *out, uint32_t limit)
{
    uint32_t i;

    for (i = 0; i < log->count && i < limit; i++) {
        const struct log_entry *e = &log->entries[i];

        fprintf(out, "    tick %-6llu turn %-3u %-12s thing %-4u (%d, %d)",
                (unsigned long long)e->tick,
                (unsigned)e->turn,
                verb_name(e->verb),
                (unsigned)e->subject,
                (int)e->ax,
                (int)e->ay);

        if (e->refusal != REFUSED_NOT_AT_ALL) {
            fprintf(out, "  REFUSED: %s", refusal_sentence(e->refusal));
        }

        fprintf(out, "\n");
    }
}
/* }}} */
