# Memory model

Three steps, each only adopted when the previous one stops being
enough. We start where the kernel is smallest and grow only as
specific needs force it.

## Step one — flat memory, no MMU configured

At launch (through phase 8) the device runs with the MMU
disabled. Every pointer is a real physical address. The kernel,
the soramech runtime, the drivers, and all four apps share one
flat address space. There is no isolation between apps; a wild
pointer in any of them can corrupt anything else.

This is acceptable because the four launch apps are all written
by us, all reviewed, and all tested together. They are not
adversarial and they are not untrusted. The simplicity buys us a
much smaller kernel — no page tables, no translation, no fault
handlers.

## Step two — MMU in protection-only mode

In phase 9, the MMU is turned on but used only for protection,
not for translation. Each app is assigned a region of physical
memory, and the MMU is configured to trap any access from that
app's threads to addresses outside its region. There is still
only one address space. A pointer still names a real physical
address. But a buggy app can no longer scribble over the kernel
or its neighbors — instead, the bad write traps, and the kernel
kills the offending app and reports the fault.

This is the model that lets us run apps written *on the device
itself*. On-device authoring guarantees we will write buggy code,
because writing buggy code is what authoring is. Protection-only
mode is the small amount of MMU work that makes the buggy code
tolerable.

## Step three — full virtual memory

Not planned. Full virtual memory means each app sees its own
private address space starting at zero, with the MMU translating
every memory access through per-app page tables. It buys us
swapping (paging memory out to disk when RAM is tight), per-app
private virtual layouts, and stronger isolation. None of those
are needed for the launch apps, and the engineering cost is much
larger than step two.

If we ever need step three — for example, if a user is running
many simultaneous custom apps and they don't all fit in RAM at
once — we will know, because we will be hitting "out of memory"
errors that no other fix addresses. Until then, step two is
enough.

## Why this matters early

The choice of memory model determines everything about how
drivers, the runtime, and apps allocate and pass around memory.
Phase 1 commits us to step one. Phase 9 commits us to step two.
The shape of the kernel API between them must be designed so
that adding step two doesn't require rewriting every allocator
and every pointer-passing convention.

That means: even in step one, allocations are made through a
kernel-mediated interface that knows which app is asking, even
though the answer it returns is still a real physical address.
When step two arrives, the interface stays the same; only the
answer changes (and the access checks the MMU performs on every
load and store get turned on).
