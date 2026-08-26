/*
 * 056-protocol.h -- bytecode for a small machine, in both directions.
 *
 * An opcode, then a chain of flag words saying which operands came along, then
 * the operands in bit order. NOBODY SENDS A LENGTH, so nobody can lie about one:
 * the flags say what is present, each present operand has a fixed width from a
 * table, and the total follows.
 *
 * The decoder writes into a register file -- fixed slots, allocated once, reused
 * by every instruction. Nothing allocates while decoding, and there is no
 * variable-length destination anywhere in the receive path.
 *
 *   The values a slot accepts are exactly the values its bits can hold. Anything
 *   outside that range is not rejected -- it is inexpressible.
 *
 * A sixteen-bit angle slot has 65,536 legal values and no illegal ones. The
 * format makes the invalid unrepresentable, which beats checking for it, because
 * a check can be forgotten and a bit width cannot.
 *
 * REFERENCES ARE THE EXCEPTION. A 32-bit index is a perfectly legal number that
 * points past the end of an array, and that is refused rather than clamped --
 * clamping would aim a command at whichever body happened to be last.
 *
 * See docs/010-commands-enter-through-one-door.md and issues 403, 405, 406.
 */

#ifndef VTT_PROTOCOL_H
#define VTT_PROTOCOL_H

#include <stdint.h>

/*
 * Seven flags per word, plus the continuation bit at position 0. A byte is the
 * natural size and seven flags is more than any instruction here needs, which is
 * a good sign the width is right rather than merely convenient.
 */
#define PROTO_FLAG_BITS   8
#define PROTO_SLOTS_PER_WORD 7

/*
 * How many flag words the decoder will read before giving up. A HARD LIMIT, not
 * a hint: it is what keeps a self-terminating format from being a way to make
 * the server read forever, and it is what lets the flag buffer be pre-sized.
 *
 * The default is deliberately small. A server that listens for five words when
 * it understands one is advertising an attack surface it does not use.
 */
#define PROTO_MAX_FLAG_WORDS 2
#define PROTO_MAX_SLOTS      (PROTO_MAX_FLAG_WORDS * PROTO_SLOTS_PER_WORD)

/* ------------------------------------------------------------------------- *
 * Opcodes
 *
 * Client to server are the verbs that already exist in 051-commandlog.h, so the
 * numbers match -- one table, not two that could drift.
 * ------------------------------------------------------------------------- */

#define OP_HELLO      64u   /* Server: who you are, and how big the world is. */
#define OP_TICK       65u   /* Server: a beat has happened. */
#define OP_WALL       66u   /* Server: a wall you are allowed to know about. */
#define OP_THING      67u   /* Server: a body you can see. */
#define OP_FAN        68u   /* Server: one boundary of your visibility. */
#define OP_REFUSAL    69u   /* Server: what you asked for, and why not. */
#define OP_RECALL     70u   /* Server: the last stretch did not happen. */
#define OP_END        71u   /* Server: that is the whole update. */
/*
 * Server: one layer of what a body looks like.
 *
 * THE PAINTBRUSH TRAVELS AS NUMBERS. Every move a sprite is allowed to make is a
 * small integer -- a shape, a colour, two offsets, a radius -- so an appearance
 * fits the protocol this project already has, and a view becomes a RENDERER OF
 * THE PAINTBRUSH rather than a second copy of the generator.
 *
 * That distinction is the whole reason it is done this way. The alternatives were
 * porting the generator to JavaScript, which is a second implementation that must
 * agree byte for byte over arithmetic JavaScript does not have; or sending the
 * SVG text, which the wire has no field for. Both end with two things that can
 * disagree about what a goblin looks like, with no error anywhere.
 */
#define OP_LAYER      72u

#define OP_FIRST_SERVER OP_HELLO
#define OP_LAST_SERVER  OP_LAYER

/* Why an instruction could not be decoded at all. These close the socket. */
#define PROTO_OK              0u
#define PROTO_UNKNOWN_OPCODE  1u
#define PROTO_CHAIN_TOO_LONG  2u
#define PROTO_TRUNCATED       3u
#define PROTO_NO_ROOM         4u

/*
 * One decoded instruction, sitting in the register file.
 *
 * `slot` is indexed by flag position: slot[0] is the operand for flag bit 1 of
 * the first word, and so on. `present` says which ones actually arrived.
 */
struct instruction {
    uint8_t  opcode;
    uint32_t present;                    /* Bit per slot. */
    uint32_t slot[PROTO_MAX_SLOTS];
};

/* A growable buffer of bytes on their way to or from a socket. */
struct byte_buffer {
    uint8_t *bytes;
    uint32_t count;
    uint32_t capacity;
    uint32_t read_position;
};

int  buffer_init(struct byte_buffer *b, uint32_t capacity);
void buffer_release(struct byte_buffer *b);
void buffer_clear(struct byte_buffer *b);

/* How many bytes are still unread. */
uint32_t buffer_remaining(const struct byte_buffer *b);

/*
 * Whether a byte sequence appears anywhere in the buffer. What the leak test
 * uses: it searches the RAW BYTES rather than asking the filter whether it would
 * have sent something, because asking the filter is asking the accused.
 */
int buffer_contains(const struct byte_buffer *b, const uint8_t *needle, uint32_t length);

/* Prepare an instruction with no operands. */
void instruction_begin(struct instruction *in, uint8_t opcode);

/*
 * Put a value in a slot and mark it present. A value wider than the slot is
 * TRUNCATED TO THE SLOT'S WIDTH, which is not an error being swallowed -- it is
 * what a fixed-width field is, the same way storing a position rounds it to the
 * nearest thousandth of a metre.
 */
void instruction_set(struct instruction *in, uint32_t slot, uint32_t value);

/* Whether a slot arrived, and what was in it. An absent slot reads as zero. */
int      instruction_has(const struct instruction *in, uint32_t slot);
uint32_t instruction_get(const struct instruction *in, uint32_t slot);

/*
 * Write an instruction into a buffer. Canonical: one encoding per instruction,
 * so a log can be diffed byte for byte rather than interpreted.
 * Returns 1 on success, 0 if the buffer could not grow.
 */
int instruction_encode(const struct instruction *in, struct byte_buffer *out);

/*
 * Read the next instruction out of a buffer. Returns PROTO_OK, or a reason.
 *
 * Every reason here CLOSES THE SOCKET rather than refusing in words. There is
 * nobody honest on the other end to explain anything to, and composing a
 * sentence for a sender who is not speaking the language is work done for an
 * attacker.
 */
uint8_t instruction_decode(struct instruction *in, struct byte_buffer *from);

/* The name of an opcode, for a demo or a dump. */
const char *opcode_name(uint8_t opcode);

/* How wide a slot is for a given opcode, in bits. */
uint8_t opcode_slot_bits(uint8_t opcode, uint32_t slot);

/* How many slots an opcode uses. */
uint32_t opcode_slot_count(uint8_t opcode);

#endif
