/*
 * 051-commandlog.c -- the record, and the table that turns it into changes.
 *
 * Interface and reasoning are in 051-commandlog.h.
 */

#include "051-commandlog.h"
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
    { "give-scope", apply_give_scope }
};

/* {{{ uint16_t command_apply */
uint16_t command_apply(struct sim *s, const struct log_entry *entry)
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

        return verb_table[entry->verb].handle(s, entry);
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

    /* GATE 6, the ruleset, arrives in phase 7. */

    return verb_table[entry->verb].handle(s, entry);
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
