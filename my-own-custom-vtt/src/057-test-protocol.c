/*
 * 057-test-protocol.c -- can a sender lie, and can a value be illegal?
 *
 * Two questions. The first is about lengths: nobody sends one, so nobody can
 * claim an instruction is longer than it is, and the tests below try.
 *
 * The second is about slots. A slot's bits are its range, so a value outside it
 * was never expressible -- the narrowing is not an error being swallowed, and
 * the tests pin that distinction against the one place it does NOT hold, which
 * is a reference.
 */

#include "020-test-harness.h"
#include "056-protocol.h"
#include "051-commandlog.h"

#include <string.h>

/* {{{ static void test_round_trip */
static void test_round_trip(void)
{
    struct byte_buffer wire;
    struct instruction sent;
    struct instruction got;

    TEST_CASE("an instruction survives being encoded and decoded");

    CHECK(buffer_init(&wire, 64) == 1);

    instruction_begin(&sent, VERB_DRIVE);
    instruction_set(&sent, 0, 42);        /* subject */
    instruction_set(&sent, 1, WA_QUARTER); /* direction */
    instruction_set(&sent, 2, 1024);      /* speed */

    CHECK(instruction_encode(&sent, &wire) == 1);
    CHECK_EQ(instruction_decode(&got, &wire), PROTO_OK);

    CHECK_EQ(got.opcode, VERB_DRIVE);
    CHECK_EQ(instruction_get(&got, 0), 42);
    CHECK_EQ(instruction_get(&got, 1), WA_QUARTER);
    CHECK_EQ(instruction_get(&got, 2), 1024);

    TEST_CASE("absent slots stay absent and read as nothing");

    {
        struct byte_buffer w2;
        struct instruction partial;
        struct instruction back;

        buffer_init(&w2, 64);

        instruction_begin(&partial, VERB_ORDER_STOP);
        instruction_set(&partial, 0, 7);

        CHECK(instruction_encode(&partial, &w2) == 1);
        CHECK_EQ(instruction_decode(&back, &w2), PROTO_OK);

        CHECK(instruction_has(&back, 0) == 1);
        CHECK(instruction_has(&back, 1) == 0);
        CHECK_EQ(instruction_get(&back, 1), 0);

        buffer_release(&w2);
    }

    buffer_release(&wire);
}
/* }}} */

/* {{{ static void test_the_encoding_is_canonical */
static void test_the_encoding_is_canonical(void)
{
    struct byte_buffer first;
    struct byte_buffer second;
    struct instruction sent;
    struct instruction got;

    TEST_CASE("one instruction has exactly one encoding");

    /*
     * What lets a command log be diffed byte for byte rather than interpreted.
     * Encode, decode, encode again -- and the bytes must match, or two runs that
     * did the same thing could look different.
     */
    CHECK(buffer_init(&first, 64) == 1);
    CHECK(buffer_init(&second, 64) == 1);

    instruction_begin(&sent, VERB_ORDER_MOVE);
    instruction_set(&sent, 0, 3);
    instruction_set(&sent, 1, 12345);
    instruction_set(&sent, 2, 67890);

    CHECK(instruction_encode(&sent, &first) == 1);
    CHECK_EQ(instruction_decode(&got, &first), PROTO_OK);
    CHECK(instruction_encode(&got, &second) == 1);

    CHECK_EQ(second.count, first.count);
    CHECK_EQ(memcmp(first.bytes, second.bytes, first.count), 0);

    buffer_release(&first);
    buffer_release(&second);
}
/* }}} */

/* {{{ static void test_nobody_sends_a_length */
static void test_nobody_sends_a_length(void)
{
    struct byte_buffer wire;
    struct instruction a;
    struct instruction b;
    struct instruction got;

    TEST_CASE("two instructions back to back decode without a length between them");

    /*
     * The flags say what is present and each present operand has a fixed width,
     * so the total follows. There is no length field, which means there is no
     * length field to lie about.
     */
    CHECK(buffer_init(&wire, 128) == 1);

    instruction_begin(&a, VERB_DRIVE);
    instruction_set(&a, 0, 1);
    instruction_set(&a, 1, 100);

    instruction_begin(&b, VERB_ORDER_STOP);
    instruction_set(&b, 0, 2);

    CHECK(instruction_encode(&a, &wire) == 1);
    CHECK(instruction_encode(&b, &wire) == 1);

    CHECK_EQ(instruction_decode(&got, &wire), PROTO_OK);
    CHECK_EQ(got.opcode, VERB_DRIVE);
    CHECK_EQ(instruction_get(&got, 0), 1);

    CHECK_EQ(instruction_decode(&got, &wire), PROTO_OK);
    CHECK_EQ(got.opcode, VERB_ORDER_STOP);
    CHECK_EQ(instruction_get(&got, 0), 2);

    CHECK_EQ(buffer_remaining(&wire), 0);

    buffer_release(&wire);
}
/* }}} */

/* {{{ static void test_a_slots_bits_are_its_range */
static void test_a_slots_bits_are_its_range(void)
{
    struct byte_buffer wire;
    struct instruction sent;
    struct instruction got;

    TEST_CASE("a value wider than its slot is narrowed, not refused");

    /*
     * The direction slot is sixteen bits, and all 65,536 patterns are legal
     * angles because a full turn is 65,536. There is no such thing as an
     * out-of-range angle, so this is not an error being swallowed -- it is what
     * a fixed-width field IS, the same way storing a position rounds it to the
     * nearest thousandth of a metre.
     */
    CHECK(buffer_init(&wire, 64) == 1);

    instruction_begin(&sent, VERB_DRIVE);
    instruction_set(&sent, 0, 5);
    instruction_set(&sent, 1, 65536 + 7);   /* a full turn plus seven */

    CHECK(instruction_encode(&sent, &wire) == 1);
    CHECK_EQ(instruction_decode(&got, &wire), PROTO_OK);

    /* Which is seven. Exactly as turning all the way round and a bit should be. */
    CHECK_EQ(instruction_get(&got, 1), 7);

    TEST_CASE("a slot the opcode does not have cannot be filled");

    {
        struct instruction stray;

        instruction_begin(&stray, VERB_ORDER_STOP);
        instruction_set(&stray, 5, 999);   /* order-stop has one slot */

        CHECK(instruction_has(&stray, 5) == 0);
    }

    buffer_release(&wire);
}
/* }}} */

/* {{{ static void test_the_ways_it_closes_the_socket */
static void test_the_ways_it_closes_the_socket(void)
{
    struct byte_buffer wire;
    struct instruction got;

    TEST_CASE("an opcode with no row is not a command at all");

    /*
     * Not a malformed command -- not a command. The socket closes; there is
     * nothing to explain to a sender who is not speaking the language, and
     * composing a sentence for one is work done for an attacker.
     */
    CHECK(buffer_init(&wire, 64) == 1);
    wire.bytes[0] = 200;   /* no such opcode */
    wire.bytes[1] = 0;
    wire.count = 2;

    CHECK_EQ(instruction_decode(&got, &wire), PROTO_UNKNOWN_OPCODE);

    TEST_CASE("verb zero is not something anybody may send");

    buffer_clear(&wire);
    wire.bytes[0] = 0;
    wire.bytes[1] = 0;
    wire.count = 2;

    CHECK_EQ(instruction_decode(&got, &wire), PROTO_UNKNOWN_OPCODE);

    TEST_CASE("a flag chain that never ends is cut off at the configured limit");

    /*
     * The bound is what keeps a self-terminating format from being a way to make
     * the server read forever. A sender setting the continuation bit on every
     * word costs a fixed and tiny amount of work.
     */
    buffer_clear(&wire);
    {
        uint32_t i;
        wire.bytes[0] = VERB_DRIVE;
        for (i = 1; i < 40; i++) {
            wire.bytes[i] = 0xFF;   /* continuation bit set, forever */
        }
        wire.count = 40;
    }

    CHECK_EQ(instruction_decode(&got, &wire), PROTO_CHAIN_TOO_LONG);

    TEST_CASE("an instruction cut short mid-operand is refused, not half-read");

    buffer_clear(&wire);
    {
        struct byte_buffer complete;
        struct instruction sent;

        buffer_init(&complete, 64);
        instruction_begin(&sent, VERB_ORDER_MOVE);
        instruction_set(&sent, 0, 1);
        instruction_set(&sent, 1, 2);
        instruction_set(&sent, 2, 3);
        instruction_encode(&sent, &complete);

        /* Chop it off part-way through the operands. */
        memcpy(wire.bytes, complete.bytes, complete.count - 3);
        wire.count = complete.count - 3;

        CHECK_EQ(instruction_decode(&got, &wire), PROTO_TRUNCATED);

        buffer_release(&complete);
    }

    TEST_CASE("an empty buffer is truncated rather than anything else");

    buffer_clear(&wire);
    CHECK_EQ(instruction_decode(&got, &wire), PROTO_TRUNCATED);

    buffer_release(&wire);
}
/* }}} */

/* {{{ static void test_flags_are_positional */
static void test_flags_are_positional(void)
{
    struct byte_buffer wire;
    struct instruction sent;
    struct instruction got;

    TEST_CASE("flags are independent questions, not one number");

    /*
     * Three bits are three separate questions, not one question with eight
     * answers. Which means slot 2 can be present while slot 1 is absent -- an
     * integer encoding could not express that without somebody defining a value
     * meaning "the third but not the second".
     */
    CHECK(buffer_init(&wire, 64) == 1);

    instruction_begin(&sent, VERB_ORDER_MOVE);
    instruction_set(&sent, 0, 11);
    instruction_set(&sent, 2, 33);   /* slot 1 deliberately left out */

    CHECK(instruction_encode(&sent, &wire) == 1);
    CHECK_EQ(instruction_decode(&got, &wire), PROTO_OK);

    CHECK(instruction_has(&got, 0) == 1);
    CHECK(instruction_has(&got, 1) == 0);
    CHECK(instruction_has(&got, 2) == 1);

    CHECK_EQ(instruction_get(&got, 0), 11);
    CHECK_EQ(instruction_get(&got, 2), 33);

    buffer_release(&wire);
}
/* }}} */

/* {{{ static void test_server_instructions */
static void test_server_instructions(void)
{
    struct byte_buffer wire;
    struct instruction sent;
    struct instruction got;

    TEST_CASE("what the server sends round-trips too");

    CHECK(buffer_init(&wire, 256) == 1);

    instruction_begin(&sent, OP_THING);
    instruction_set(&sent, 0, 17);          /* index */
    instruction_set(&sent, 1, 5000);        /* x */
    instruction_set(&sent, 2, 6000);        /* y */
    instruction_set(&sent, 3, WA_QUARTER);  /* facing */
    instruction_set(&sent, 4, 512);         /* radius */
    instruction_set(&sent, 5, 3);           /* kind */

    CHECK(instruction_encode(&sent, &wire) == 1);
    CHECK_EQ(instruction_decode(&got, &wire), PROTO_OK);

    CHECK_EQ(got.opcode, OP_THING);
    CHECK_EQ(instruction_get(&got, 0), 17);
    CHECK_EQ(instruction_get(&got, 3), WA_QUARTER);
    CHECK_EQ(instruction_get(&got, 5), 3);

    TEST_CASE("every opcode has a name and a slot count");

    {
        uint8_t op;
        for (op = OP_FIRST_SERVER; op <= OP_LAST_SERVER; op++) {
            CHECK(opcode_name(op)[0] != '\0');
            CHECK(opcode_slot_count(op) > 0);
        }
        for (op = 1; op < VERB_COUNT; op++) {
            CHECK(opcode_name(op)[0] != '\0');
            CHECK(opcode_slot_count(op) > 0);
        }
    }

    buffer_release(&wire);
}
/* }}} */

/* {{{ static void test_the_leak_tests_instrument */
static void test_the_leak_tests_instrument(void)
{
    struct byte_buffer wire;
    struct instruction sent;
    uint8_t needle[4];

    TEST_CASE("the byte search can find what is there");

    /*
     * The leak test's instrument, checked before it is trusted. A search that
     * cannot detect the thing it looks for would retire a suspicion rather than
     * settle it -- which is worse than not testing at all.
     */
    CHECK(buffer_init(&wire, 128) == 1);

    instruction_begin(&sent, OP_THING);
    instruction_set(&sent, 1, 0x11223344u);
    instruction_encode(&sent, &wire);

    needle[0] = 0x44; needle[1] = 0x33; needle[2] = 0x22; needle[3] = 0x11;
    CHECK(buffer_contains(&wire, needle, 4) == 1);

    TEST_CASE("and does not find what is not");

    needle[0] = 0xDE; needle[1] = 0xAD; needle[2] = 0xBE; needle[3] = 0xEF;
    CHECK(buffer_contains(&wire, needle, 4) == 0);

    buffer_release(&wire);
}
/* }}} */

/* {{{ int main */
int main(void)
{
    test_round_trip();
    test_the_encoding_is_canonical();
    test_nobody_sends_a_length();
    test_a_slots_bits_are_its_range();
    test_the_ways_it_closes_the_socket();
    test_flags_are_positional();
    test_server_instructions();
    test_the_leak_tests_instrument();

    return vtt_test_finish("057-test-protocol");
}
/* }}} */
