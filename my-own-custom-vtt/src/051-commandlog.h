/*
 * 051-commandlog.h -- everything anybody asked for, in order, including the
 * parts they regretted.
 *
 * A snapshot plus the commands that followed it reproduces a session exactly.
 * That is true only because the tick is deterministic, and the tick is
 * deterministic only because of the integer arithmetic and buffer-then-resolve
 * decisions made earlier.
 *
 * THIS IS NOT AN APPEND-ONLY STREAM OF OPAQUE BYTES, and that is deliberate.
 * A retcon -- restore the head of a turn, change one command, replay forward --
 * needs a record that can be indexed by turn, read back, altered, and replayed.
 * So commands are stored DECODED, as the values they became rather than the
 * bytes they arrived as.
 *
 * Refused commands are kept too, marked. A log that quietly drops them cannot
 * answer "why did nothing happen when I pressed that", which is the most direct
 * evidence there is about where an interface confuses people.
 *
 * See docs/010-commands-enter-through-one-door.md and
 * issues/306-the-command-log-is-the-replay.md.
 */

#ifndef VTT_COMMANDLOG_H
#define VTT_COMMANDLOG_H

#include <stdint.h>
#include <stdio.h>

#include "049-tick.h"

/*
 * The verbs. A dispatch table, not a switch -- adding a command is adding a row.
 * Phase 4 gives these opcodes on a wire; here they are already decoded.
 */
#define VERB_NONE        0u
#define VERB_DRIVE       1u   /* A direction being pushed. */
#define VERB_ORDER_MOVE  2u   /* Walk to a point. */
#define VERB_ORDER_FACE  3u   /* Look at a point. */
#define VERB_ORDER_STOP  4u   /* Cancel standing orders. */
#define VERB_COUNT       5u

/* Why a command was refused. Every refusal is a sentence, not a number. */
#define REFUSED_NOT_AT_ALL       0u
#define REFUSED_UNKNOWN_VERB     1u
#define REFUSED_NO_SUCH_SUBJECT  2u
#define REFUSED_SUBJECT_IS_NOTHING 3u

struct log_entry {
    uint64_t tick;
    uint32_t turn;
    uint32_t viewer;     /* 0 until phase 4, when commands arrive on sockets. */

    uint16_t verb;
    uint16_t refusal;    /* REFUSED_NOT_AT_ALL means it was accepted. */

    uint32_t subject;    /* Which thing. */
    int32_t  ax;         /* Two general-purpose arguments. What they mean is */
    int32_t  ay;         /* the verb's business. */
};

struct command_log {
    struct log_entry *entries;
    uint32_t          count;
    uint32_t          capacity;

    /*
     * Where each turn's commands begin. Indexed rather than scanned, so that
     * finding the head of a turn to roll back to is a lookup.
     */
    uint32_t *turn_start;
    uint32_t  turn_capacity;
    uint32_t  turn_count;
};

int  log_init(struct command_log *log, uint32_t capacity);
void log_release(struct command_log *log);

/* Start a new turn. Every command after this belongs to it. */
int log_begin_turn(struct command_log *log, uint32_t turn);

/*
 * Record a command. Called at decode time, BEFORE the gauntlet runs, so that a
 * refusal is recorded with its reason rather than being absent.
 * Returns the entry's index, or the count on failure to grow.
 */
uint32_t log_record(struct command_log *log, const struct log_entry *entry);

/* Mark an already-recorded command as refused. */
void log_mark_refused(struct command_log *log, uint32_t index, uint16_t refusal);

/* Where a turn's commands begin, and how many there are. */
uint32_t log_turn_first(const struct command_log *log, uint32_t turn);
uint32_t log_turn_count(const struct command_log *log, uint32_t turn);

/*
 * Rewrite one command. THIS IS WHAT A RETCON IS -- the GM ruled wrongly, and
 * everything downstream should follow from the correction.
 *
 * It is also the dangerous one, because it changes what somebody did without
 * asking them. Who may do it is open question 3.4.
 */
void log_rewrite(struct command_log *log, uint32_t index, const struct log_entry *entry);

/*
 * Apply one command to a simulation. The dispatch table. Returns the refusal
 * reason, or REFUSED_NOT_AT_ALL if it was accepted.
 */
uint16_t command_apply(struct sim *s, const struct log_entry *entry);

/* A refusal as a sentence. Never a number, and never silence. */
const char *refusal_sentence(uint16_t refusal);

/* The name of a verb, for a demo or a log dump. */
const char *verb_name(uint16_t verb);

/* How many commands were refused. What a demo reports. */
uint32_t log_refused_count(const struct command_log *log);

/* Write the log out as text, so a person can read what everybody tried. */
void log_dump(const struct command_log *log, FILE *out, uint32_t limit);

#endif
