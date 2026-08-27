/*
 * 056-protocol.c -- the flag chain, the slot table, and the register file.
 *
 * Interface and reasoning are in 056-protocol.h.
 *
 * The slot table below is the whole grammar. Adding an operand to an instruction
 * is adding a number to a row; adding an instruction is adding a row. There is no
 * parser, only a walk over set bits into slots of known width.
 */

#include "056-protocol.h"
#include "051-commandlog.h"

#include <stdlib.h>
#include <string.h>

/*
 * How wide each slot is, per opcode. A zero ends the row.
 *
 * Widths are chosen so that every legal value fits and no illegal one can be
 * expressed: sixteen bits for an angle because a full turn is 65,536, eight for
 * a refusal reason because there will never be 256 of them, thirty-two for a
 * coordinate or an index.
 */
struct opcode_spec {
    const char *name;
    uint8_t     bits[PROTO_MAX_SLOTS];
};

/* Client to server. The numbers match the verbs in 051-commandlog.h. */
static const struct opcode_spec inbound[VERB_COUNT] = {
    { "none",       { 0 } },
    /* drive:      subject, direction, speed */
    { "drive",      { 32, 16, 32, 0 } },
    /* order-move: subject, x, y */
    { "order-move", { 32, 32, 32, 0 } },
    /* order-face: subject, x, y */
    { "order-face", { 32, 32, 32, 0 } },
    /* order-stop: subject */
    { "order-stop", { 32, 0 } },
    /* give-scope: unused, which scope, which viewer */
    { "give-scope", { 32, 32, 32, 0 } },
    /*
     * retier: which thing, what tier
     *
     * Eight bits for a tier that runs 1 to 5. Not three, which would be the
     * tightest fit -- three bits still admit 0, 6 and 7, so it would not buy the
     * property the widths are chosen for, and it would make a field that no
     * hand-written client could produce without a bit-twiddling diagram. The
     * gate refuses anything off the scale BY NAME, which is the layer where a
     * client with a ten-point scale should be told so.
     */
    { "retier",     { 32, 8, 0 } },
    /*
     * interact: which thing, which intent
     *
     * Thirty-two bits for an intent the SERVER never interprets. Not eight: the
     * numbers belong to a ruleset's catalogue and a ruleset with three hundred
     * kinds of interaction is a ruleset this server should be able to carry
     * without having had an opinion about how many there would be.
     */
    { "interact",   { 32, 32, 0 } }
};

/* Server to client. */
static const struct opcode_spec outbound[] = {
    /* hello:   your viewer index, min_x, min_y, max_x, max_y */
    { "hello",   { 32, 32, 32, 32, 32, 0 } },
    /* tick:    low half, high half */
    { "tick",    { 32, 32, 0 } },
    /* wall:    index, ax, ay, bx, by, flags */
    { "wall",    { 32, 32, 32, 32, 32, 16, 0 } },
    /*
     * thing: index, x, y, facing, radius, kind, motion
     *
     * The motion is eight bits and belongs on the thing rather than on a layer,
     * because the whole sprite bobs or walks or turns -- a per-layer motion would
     * be a different and much larger idea.
     */
    { "thing",   { 32, 32, 32, 16, 16, 32, 8, 0 } },
    /* fan:     angle, distance */
    { "fan",     { 16, 32, 0 } },
    /* refusal: which verb, which subject, reason */
    { "refusal", { 16, 32, 8, 0 } },
    /* recall:  the turn being taken back */
    { "recall",  { 32, 0 } },
    /* end:     how many instructions preceded this one */
    { "end",     { 32, 0 } },
    /*
     * layer: which thing, which layer, shape, colour, offset x, offset y, radius
     *
     * The COLOUR goes on the wire, not the palette slot it came from. A view
     * needs no palette and no lookup, and a slot number would be a second thing
     * to keep in step for no gain -- a view is not going to re-tint anything.
     *
     * The offsets are signed bytes sent through unsigned slots, the same way a
     * coordinate is. A reader sign-extends; a reader that forgets draws every
     * detail on one side, which is loud rather than subtle.
     */
    { "layer",   { 32, 8, 8, 32, 8, 8, 8, 0 } }
};

/* {{{ static const struct opcode_spec *spec_for */
static const struct opcode_spec *spec_for(uint8_t opcode)
{
    if (opcode < VERB_COUNT) {
        /* Verb zero is "none" and is not a thing anybody may send. */
        if (opcode == 0) {
            return NULL;
        }
        return &inbound[opcode];
    }

    if (opcode >= OP_FIRST_SERVER && opcode <= OP_LAST_SERVER) {
        return &outbound[opcode - OP_FIRST_SERVER];
    }

    return NULL;
}
/* }}} */

/* {{{ const char *opcode_name */
const char *opcode_name(uint8_t opcode)
{
    const struct opcode_spec *spec = spec_for(opcode);

    return (spec == NULL) ? "unknown" : spec->name;
}
/* }}} */

/* {{{ uint8_t opcode_slot_bits */
uint8_t opcode_slot_bits(uint8_t opcode, uint32_t slot)
{
    const struct opcode_spec *spec = spec_for(opcode);

    if (spec == NULL || slot >= PROTO_MAX_SLOTS) {
        return 0;
    }

    return spec->bits[slot];
}
/* }}} */

/* {{{ uint32_t opcode_slot_count */
uint32_t opcode_slot_count(uint8_t opcode)
{
    const struct opcode_spec *spec = spec_for(opcode);
    uint32_t i;

    if (spec == NULL) {
        return 0;
    }

    for (i = 0; i < PROTO_MAX_SLOTS; i++) {
        if (spec->bits[i] == 0) {
            return i;
        }
    }

    return PROTO_MAX_SLOTS;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * The buffer
 * ------------------------------------------------------------------------- */

/* {{{ int buffer_init */
int buffer_init(struct byte_buffer *b, uint32_t capacity)
{
    if (capacity < 64) {
        capacity = 64;
    }

    b->bytes = calloc((size_t)capacity, 1);
    if (b->bytes == NULL) {
        b->capacity = 0;
        b->count = 0;
        b->read_position = 0;
        return 0;
    }

    b->capacity = capacity;
    b->count = 0;
    b->read_position = 0;

    return 1;
}
/* }}} */

/* {{{ void buffer_release */
void buffer_release(struct byte_buffer *b)
{
    free(b->bytes);
    b->bytes = NULL;
    b->capacity = 0;
    b->count = 0;
    b->read_position = 0;
}
/* }}} */

/* {{{ void buffer_clear */
void buffer_clear(struct byte_buffer *b)
{
    b->count = 0;
    b->read_position = 0;
}
/* }}} */

/* {{{ uint32_t buffer_remaining */
uint32_t buffer_remaining(const struct byte_buffer *b)
{
    return (b->count > b->read_position) ? (b->count - b->read_position) : 0;
}
/* }}} */

/* {{{ static int buffer_put */
static int buffer_put(struct byte_buffer *b, uint8_t value)
{
    if (b->count >= b->capacity) {
        uint32_t wanted = b->capacity * 2;
        uint8_t *moved = realloc(b->bytes, (size_t)wanted);

        if (moved == NULL) {
            return 0;
        }

        b->bytes = moved;
        b->capacity = wanted;
    }

    b->bytes[b->count] = value;
    b->count++;

    return 1;
}
/* }}} */

/* {{{ static int buffer_take */
static int buffer_take(struct byte_buffer *b, uint8_t *value)
{
    if (b->read_position >= b->count) {
        return 0;
    }

    *value = b->bytes[b->read_position];
    b->read_position++;

    return 1;
}
/* }}} */

/* {{{ int buffer_contains */
int buffer_contains(const struct byte_buffer *b, const uint8_t *needle, uint32_t length)
{
    uint32_t i;

    if (length == 0 || length > b->count) {
        return 0;
    }

    /*
     * A plain scan. This is the leak test's instrument, and it deliberately
     * shares nothing with the filter it is checking -- a test that shares an
     * implementation with the thing it tests agrees with it about the bug too.
     */
    for (i = 0; i + length <= b->count; i++) {
        if (memcmp(b->bytes + i, needle, (size_t)length) == 0) {
            return 1;
        }
    }

    return 0;
}
/* }}} */

/* ------------------------------------------------------------------------- *
 * Instructions
 * ------------------------------------------------------------------------- */

/* {{{ void instruction_begin */
void instruction_begin(struct instruction *in, uint8_t opcode)
{
    memset(in, 0, sizeof(struct instruction));
    in->opcode = opcode;
}
/* }}} */

/* {{{ void instruction_set */
void instruction_set(struct instruction *in, uint32_t slot, uint32_t value)
{
    uint8_t bits;

    if (slot >= PROTO_MAX_SLOTS) {
        return;
    }

    bits = opcode_slot_bits(in->opcode, slot);
    if (bits == 0) {
        return;   /* This opcode has no such slot. */
    }

    /*
     * Narrowed to the slot's width. Not an error being swallowed: a slot's bits
     * ARE its range, so a value outside it was never expressible in the first
     * place, and this is where that becomes true rather than being asserted.
     */
    if (bits < 32) {
        value &= (uint32_t)((1u << bits) - 1u);
    }

    in->slot[slot] = value;
    in->present |= (1u << slot);
}
/* }}} */

/* {{{ int instruction_has */
int instruction_has(const struct instruction *in, uint32_t slot)
{
    if (slot >= PROTO_MAX_SLOTS) {
        return 0;
    }

    return (in->present & (1u << slot)) != 0;
}
/* }}} */

/* {{{ uint32_t instruction_get */
uint32_t instruction_get(const struct instruction *in, uint32_t slot)
{
    /*
     * An absent slot reads as zero, in keeping with the rest of the project: a
     * missing thing reads as nothing and the caller carries on. Which slots an
     * instruction requires is the handler's business, not the decoder's.
     */
    if (slot >= PROTO_MAX_SLOTS) {
        return 0;
    }

    return in->slot[slot];
}
/* }}} */

/* {{{ int instruction_encode */
int instruction_encode(const struct instruction *in, struct byte_buffer *out)
{
    uint32_t words;
    uint32_t word;
    uint32_t slot;

    if (spec_for(in->opcode) == NULL) {
        return 0;
    }

    if (!buffer_put(out, in->opcode)) {
        return 0;
    }

    /*
     * How many flag words are needed: enough to cover the highest slot actually
     * present. Canonical -- one encoding per instruction -- because a log that
     * can be diffed byte for byte is worth more than a byte saved.
     */
    words = 1;
    for (slot = 0; slot < PROTO_MAX_SLOTS; slot++) {
        if (instruction_has(in, slot)) {
            words = (slot / PROTO_SLOTS_PER_WORD) + 1;
        }
    }

    for (word = 0; word < words; word++) {
        uint8_t byte = 0;

        /* Bit 0 is the continuation bit: another word follows. */
        if (word + 1 < words) {
            byte |= 1u;
        }

        for (slot = 0; slot < PROTO_SLOTS_PER_WORD; slot++) {
            uint32_t index = (word * PROTO_SLOTS_PER_WORD) + slot;

            if (index < PROTO_MAX_SLOTS && instruction_has(in, index)) {
                byte |= (uint8_t)(1u << (slot + 1));
            }
        }

        if (!buffer_put(out, byte)) {
            return 0;
        }
    }

    /*
     * Operands in bit order, low to high, each at its slot's width. The decoder
     * walks the same order, so nothing has to be told where anything is.
     */
    for (slot = 0; slot < PROTO_MAX_SLOTS; slot++) {
        uint8_t bits;
        uint32_t value;
        uint32_t byte;

        if (!instruction_has(in, slot)) {
            continue;
        }

        bits = opcode_slot_bits(in->opcode, slot);
        value = in->slot[slot];

        for (byte = 0; byte < (uint32_t)(bits / 8); byte++) {
            if (!buffer_put(out, (uint8_t)((value >> (byte * 8)) & 0xFFu))) {
                return 0;
            }
        }
    }

    return 1;
}
/* }}} */

/* {{{ uint8_t instruction_decode */
uint8_t instruction_decode(struct instruction *in, struct byte_buffer *from)
{
    uint8_t opcode;
    uint8_t flag_bytes[PROTO_MAX_FLAG_WORDS];
    uint32_t words = 0;
    uint32_t slot;

    if (!buffer_take(from, &opcode)) {
        return PROTO_TRUNCATED;
    }

    /*
     * An opcode with no row is not a malformed command -- it is not a command at
     * all. The socket closes; there is nothing to explain to a sender who is not
     * speaking the language.
     */
    if (spec_for(opcode) == NULL) {
        return PROTO_UNKNOWN_OPCODE;
    }

    instruction_begin(in, opcode);

    /*
     * The flag chain. The continuation bit says whether another word follows, and
     * the configured maximum is what stops a sender setting it forever -- costing
     * the server a fixed and tiny amount of work rather than an unbounded read.
     */
    for (;;) {
        uint8_t byte;

        if (words >= PROTO_MAX_FLAG_WORDS) {
            return PROTO_CHAIN_TOO_LONG;
        }

        if (!buffer_take(from, &byte)) {
            return PROTO_TRUNCATED;
        }

        flag_bytes[words] = byte;
        words++;

        if ((byte & 1u) == 0) {
            break;
        }
    }

    for (words = 0; words < PROTO_MAX_FLAG_WORDS; words++) {
        uint32_t bit;

        if (words > 0 && (flag_bytes[words - 1] & 1u) == 0) {
            break;
        }

        for (bit = 0; bit < PROTO_SLOTS_PER_WORD; bit++) {
            uint32_t index = (words * PROTO_SLOTS_PER_WORD) + bit;

            if ((flag_bytes[words] & (1u << (bit + 1))) != 0 &&
                index < PROTO_MAX_SLOTS) {
                in->present |= (1u << index);
            }
        }
    }

    for (slot = 0; slot < PROTO_MAX_SLOTS; slot++) {
        uint8_t bits;
        uint32_t value = 0;
        uint32_t byte;

        if (!instruction_has(in, slot)) {
            continue;
        }

        bits = opcode_slot_bits(opcode, slot);

        /*
         * A flag set for a slot this opcode does not have. The sender is not
         * speaking the language, so the socket closes rather than the flag being
         * quietly ignored -- ignoring it would mean the operands after it are
         * read at the wrong offsets and everything downstream is nonsense that
         * looks like data.
         */
        if (bits == 0) {
            return PROTO_UNKNOWN_OPCODE;
        }

        for (byte = 0; byte < (uint32_t)(bits / 8); byte++) {
            uint8_t piece;

            if (!buffer_take(from, &piece)) {
                return PROTO_TRUNCATED;
            }

            value |= ((uint32_t)piece) << (byte * 8);
        }

        in->slot[slot] = value;
    }

    return PROTO_OK;
}
/* }}} */
