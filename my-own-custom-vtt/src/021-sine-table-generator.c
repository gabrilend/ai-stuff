/*
 * 021-sine-table-generator.c -- writes the trigonometry tables the server reads.
 *
 * This program runs at build time and emits a header full of integers. It is the
 * only place in the project where a floating-point number is allowed to exist,
 * and the numbers it produces are frozen into the build before the server ever
 * starts.
 *
 * The point is that nobody commits a table of magic numbers with no visible
 * origin. Make the tool, not the thing: if the angle resolution ever changes,
 * this is re-run rather than the table being hand-edited.
 *
 * Two tables come out:
 *
 *   A quarter sine table. Sine is symmetric, so a quarter turn is enough to
 *   derive the whole circle by reflection, and a quarter costs 64 kilobytes
 *   where a full circle would cost 256 and thrash the cache for nothing.
 *
 *   An arctangent table, used to turn a vector back into an angle. It covers one
 *   eighth of a turn -- the slice where the vector's smaller component is the
 *   numerator -- and the other seven eighths come from signs and a swap.
 *
 * Usage:  021-sine-table-generator > 021-trig-table.h
 */

#include <stdio.h>
#include <math.h>

/* Must match WC_SHIFT and the angle constants in 021-fixed-point.h. */
#define SIN_SHIFT   16
#define SIN_ONE     (1 << SIN_SHIFT)
#define WA_QUARTER  16384
#define WA_EIGHTH   8192
#define ATAN_STEPS  1024

/*
 * Spelled out rather than taken from M_PI, which is a POSIX extension and not
 * part of C99 -- so a strict-C99 build does not have it. Written to more digits
 * than a double can hold, so that the constant is not the thing limiting the
 * table's accuracy.
 */
#define TAU 6.283185307179586476925286766559

/* {{{ static void emit_sine_table */
static void emit_sine_table(void)
{
    int i;

    printf("/* Quarter turn of sine, scaled so that %d is 1.0. */\n", SIN_ONE);
    printf("static const int32_t trig_sine_quarter[%d] = {\n", WA_QUARTER + 1);

    /*
     * WA_QUARTER + 1 entries, not WA_QUARTER. The extra final entry is sin at
     * exactly a quarter turn, which is 1.0. Without it every reflection has to
     * special-case the endpoint, and one of them eventually will not.
     */
    for (i = 0; i <= WA_QUARTER; i++) {
        double radians = (double)i * TAU / 65536.0;
        double value   = sin(radians) * (double)SIN_ONE;

        /* Round to nearest rather than truncating, so the table is symmetric. */
        long rounded = (long)(value + 0.5);

        printf("    %ld%s", rounded, (i == WA_QUARTER) ? "\n" : ",");
        if ((i % 8) == 7) {
            printf("\n");
        }
    }

    printf("};\n\n");
}
/* }}} */

/* {{{ static void emit_arctan_table */
static void emit_arctan_table(void)
{
    int i;

    printf("/* arctan(i/%d), in angle units, covering one eighth of a turn. */\n",
           ATAN_STEPS);
    printf("static const uint16_t trig_arctan[%d] = {\n", ATAN_STEPS + 1);

    for (i = 0; i <= ATAN_STEPS; i++) {
        double ratio   = (double)i / (double)ATAN_STEPS;
        double radians = atan(ratio);
        double units   = radians * 65536.0 / TAU;

        long rounded = (long)(units + 0.5);

        printf("    %ld%s", rounded, (i == ATAN_STEPS) ? "\n" : ",");
        if ((i % 8) == 7) {
            printf("\n");
        }
    }

    printf("};\n\n");
}
/* }}} */

/* {{{ int main */
int main(void)
{
    printf("/*\n");
    printf(" * 021-trig-table.h -- GENERATED. Do not edit.\n");
    printf(" *\n");
    printf(" * Produced by 021-sine-table-generator.c. If these numbers are\n");
    printf(" * wrong, fix the generator and re-run the build; editing this file\n");
    printf(" * makes it disagree with the tool that claims to produce it.\n");
    printf(" */\n\n");
    printf("#ifndef VTT_TRIG_TABLE_H\n");
    printf("#define VTT_TRIG_TABLE_H\n\n");
    printf("#include <stdint.h>\n\n");

    emit_sine_table();
    emit_arctan_table();

    printf("#endif\n");
    return 0;
}
/* }}} */
