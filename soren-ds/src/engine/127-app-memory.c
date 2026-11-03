/*
 * 127-app-memory.c — memory that belongs to one app: the STAND-IN for
 * issue 902's per-app region.
 *
 * General description: a budget per app, kept under one lock, and the
 * memory itself from the engine's block allocator on behalf of whichever
 * core (or the outside owner) is asking. When 902 lands, the two calls
 * that take and give back memory become page_alloc_for_app and its
 * partner, and the budget becomes the region's size.
 */
#include <stdint.h>
#include <stddef.h>
#include "025-platform.h"
#include "027-primitives.h"
#include "029-blocks.h"
#include "031-engine-internal.h"
#include "127-app-memory.h"

struct app_budget {
    size_t   held;
    size_t   limit;                    /* 0: never set, so the default */
    struct app_memory_counts counts;
};

static struct app_budget budgets[APP_MEMORY_APPS];
static spin_lock_t budget_lock = SPIN_LOCK_INIT;

/* {{{ limit_of */
static size_t limit_of(const struct app_budget *b)
{
    return b->limit ? b->limit : APP_MEMORY_DEFAULT_LIMIT;
}
/* }}} */

/* {{{ app_memory_alloc */
void *app_memory_alloc(int app, size_t bytes)
{
    if (app < 0 || app >= APP_MEMORY_APPS || bytes == 0) {
        return NULL;
    }
    struct app_budget *b = &budgets[app];
    /* Reserve the bytes first, so two cores asking at once cannot both
     * fit under the budget that only one of them fits under. */
    spin_lock(&budget_lock);
    int fits = b->held + bytes >= b->held && b->held + bytes <= limit_of(b);
    if (fits) {
        b->held += bytes;
        b->counts.taken++;
    } else {
        b->counts.refused++;
    }
    spin_unlock(&budget_lock);
    if (!fits) {
        return NULL;
    }
    struct core_ctx *c = engine_enter();
    void *memory = block_alloc_zero(c->number, bytes);
    engine_leave(c);
    if (!memory) {
        spin_lock(&budget_lock);
        b->held -= bytes;
        b->counts.taken--;
        b->counts.refused++;
        spin_unlock(&budget_lock);
    }
    return memory;
}
/* }}} */

/* {{{ app_memory_free */
void app_memory_free(int app, void *memory, size_t bytes)
{
    if (!memory || app < 0 || app >= APP_MEMORY_APPS) {
        return;
    }
    struct core_ctx *c = engine_enter();
    block_free(c->number, memory);
    engine_leave(c);
    struct app_budget *b = &budgets[app];
    spin_lock(&budget_lock);
    b->held = b->held >= bytes ? b->held - bytes : 0;
    b->counts.given_back++;
    spin_unlock(&budget_lock);
}
/* }}} */

/* {{{ the budget */
size_t app_memory_held(int app)
{
    if (app < 0 || app >= APP_MEMORY_APPS) {
        return 0;
    }
    spin_lock(&budget_lock);
    size_t held = budgets[app].held;
    spin_unlock(&budget_lock);
    return held;
}

size_t app_memory_limit(int app)
{
    if (app < 0 || app >= APP_MEMORY_APPS) {
        return 0;
    }
    spin_lock(&budget_lock);
    size_t limit = limit_of(&budgets[app]);
    spin_unlock(&budget_lock);
    return limit;
}

void app_memory_set_limit(int app, size_t bytes)
{
    if (app < 0 || app >= APP_MEMORY_APPS || bytes == 0) {
        return;
    }
    spin_lock(&budget_lock);
    budgets[app].limit = bytes;
    spin_unlock(&budget_lock);
}

struct app_memory_counts app_memory_counts(int app)
{
    struct app_memory_counts out = { 0, 0, 0 };
    if (app >= 0 && app < APP_MEMORY_APPS) {
        spin_lock(&budget_lock);
        out = budgets[app].counts;
        spin_unlock(&budget_lock);
    }
    return out;
}
/* }}} */
