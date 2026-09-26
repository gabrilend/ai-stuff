/*
 * 035-tasks.c — one run of one station, made concrete (issue 210).
 *
 * General description: a task is built the moment a station's inputs are
 * all present, by the core that noticed, and freed by the core that ran
 * it. It is one allocation sized exactly for its box — a header, the
 * box's parameters packed at the offsets the box states, then room for
 * the return value — and it holds copies, so once built it depends on
 * nothing another core can change. Two runs of one station can therefore
 * happen at once without meeting.
 *
 *   ┌────────┬─────────┬──────┬─────────────────┬─────────────┐
 *   │ box    │ station │ exit │ input bytes     │ return bytes│
 *   └────────┴─────────┴──────┴─────────────────┴─────────────┘
 *   ◀────── header ─────────▶◀──── sized per box ────────────▶
 */
#include "031-engine-internal.h"

/* {{{ task_bytes */
size_t task_bytes(const struct box *box)
{
    return sizeof(struct task) + round_up_pow2(box->in_bytes, 8) + round_up_pow2(box->return_size, 8);
}
/* }}} */

/* {{{ task_build */
struct task *task_build(struct core_ctx *c, struct station *s, int32_t index, void **claimed)
{
    const struct box *box = s->box;
    struct task *t = block_alloc(c->number, task_bytes(box));
    if (!t) {
        return (struct task *)0;
    }
    t->box       = box;
    t->station   = index;
    t->exit      = choose_exit_at_claim(s);
    t->in_bytes  = box->in_bytes;
    t->out_bytes = box->return_size;
    t->out       = t->in + round_up_pow2(box->in_bytes, 8);

    /* Two sources for each parameter: a claimed cell (a ring port — copy
     * the value out of the cell, which the caller then marks empty) or
     * no cell (a static port — copy the dial's current setting). */
    for (int p = 0; p < s->n_box_ports; p++) {
        const struct box_param *param = &box->params[p];
        uint8_t *cell = claimed[p];
        if (cell) {
            bytes_copy(t->in + param->offset, cell + CELL_HEADER, param->size);
        } else {
            port_read_static(&s->ports[p], t->in + param->offset);
        }
    }
    atomic_add(&s->in_flight, 1);
    return t;
}
/* }}} */

/* {{{ task_free */
void task_free(struct core_ctx *c, struct task *t)
{
    block_free(c->number, t);
}
/* }}} */
