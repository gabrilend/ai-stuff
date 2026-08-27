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
#define VERB_GIVE_SCOPE  5u   /* Hand a scope to somebody else. */
/*
 * Say what you think of the picture a thing is wearing.
 *
 * IT CHANGES NOTHING IN THE WORLD, which is what makes it safe to send in the
 * middle of a turn -- no position moves, no hash shifts, no replay diverges. It
 * still runs the whole gauntlet, because who may re-tier a shared library is a
 * permission question like any other.
 *
 * `subject` is the thing being looked at; `ax` is the tier, 1 to 5.
 *
 * This is what makes judge-then-curate a TABLETOP idea rather than a gallery
 * one. A sprite judged in a gallery is judged as a picture; the same sprite
 * judged mid-session is judged on whether it read as a goblin at the moment it
 * needed to, at that size, in that light, next to those other things. That is a
 * better question and it can only be asked while playing.
 */
#define VERB_RETIER      6u
/*
 * Act on something you do not command.
 *
 * OWNERSHIP IS THE RIGHT TO MOVE A PIECE, not a fence around it. A forest
 * commander owns their goblin patrol and moves it. When it walks into somebody
 * else's tavern, the tavern's owner cannot move it -- and can absolutely poison
 * its drink, spring a trapdoor under it, or refuse it mead. **But they had
 * better explain how**, and that sentence is the ruleset's job.
 *
 * `subject` is the thing being acted on. `ax` is an intent number the RULESET
 * catalogues -- the server has no opinion about what any of them mean, so one
 * verb with a number is the whole of what it can honestly express.
 *
 * The gate is SIGHT, not membership: you may act on what you were told about.
 * See session_command_from, which performs it, and issue 1201.
 */
#define VERB_INTERACT    7u
#define VERB_COUNT       8u

/* Why a command was refused. Every refusal is a sentence, not a number. */
#define REFUSED_NOT_AT_ALL       0u
#define REFUSED_UNKNOWN_VERB     1u
#define REFUSED_NO_SUCH_SUBJECT  2u
#define REFUSED_SUBJECT_IS_NOTHING 3u
#define REFUSED_NOT_YOURS          4u   /* No scope of yours contains it. */
#define REFUSED_WRONG_STYLE        5u   /* Right thing, wrong kind of order. */
#define REFUSED_MAY_NOT_EDIT       6u   /* Handing a scope over is an edit. */
#define REFUSED_NO_SUCH_SCOPE      7u
/*
 * Gate 6. The only reason whose sentence the SERVER does not write -- the
 * ruleset does, because the reasons are as varied as games are. Forcing a
 * ruleset to pick from a list the server invented would be the server having
 * opinions by the back door.
 */
#define REFUSED_BY_THE_RULES       8u
/* Re-tiering needs a library to write into, and none is attached. */
#define REFUSED_NO_LIBRARY         9u
/* A tier is 1 to 5. Anything else is a caller with a different scale in mind. */
#define REFUSED_NOT_A_TIER        10u
/* The thing is not wearing a picture, so there is nothing to have an opinion of. */
#define REFUSED_WEARS_NOTHING     11u
/*
 * You cannot act on what you were not told about.
 *
 * The same rule as not being told it is there, and it must be the same DECISION
 * rather than a second one that agrees most of the time -- otherwise this becomes
 * a way to probe the dark.
 */
#define REFUSED_CANNOT_SEE_IT     12u
/* Nothing knows what your intent means. */
#define REFUSED_NO_RULES_FOR_THAT 13u
#define REFUSED_COUNT             14u

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
 * Gates 1 through 5, WITHOUT applying anything. Returns a refusal reason, or
 * REFUSED_NOT_AT_ALL.
 *
 * Separate from performing because gate 6 -- the ruleset -- sits between them,
 * and a ruleset asked to veto something that has already happened is not a veto.
 */
uint16_t command_check(struct sim *s, const struct log_entry *entry);

/* Do it. Only call this on a command that passed every gate. */
uint16_t command_perform(struct sim *s, const struct log_entry *entry);

/*
 * Check and perform, with no rules layer between. What a caller uses when there
 * is no ruleset -- tests, and the scripted driver.
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
