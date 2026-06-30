#!/usr/bin/env bash
# probe-common.sh — shared probe-engine constants and helpers for the
# lab-side scripts (flash-sd, write-probe, select-probe).
#
# General description: this file is SOURCED, not executed. It holds
# the one authoritative copy of the microSD LBA constants the probe
# engine uses, plus the helper that wraps a probe-script text file in
# the 16-byte header the kernel recognises. Keeping it in one place
# means the lab tools can never drift out of sync with each other —
# and the constants below must match src/019-probe-engine.c and the
# microSD region layout in docs/016-physical-memory-map.md.

# {{{ LBA constants — MUST match src/019-probe-engine.c
# The kernel reads the probe it runs from the ACTIVE region. The
# CATALOG holds the whole probe library in numbered slots; slot 0 is
# a plain-text manifest (name -> slot -> writes-flag), slots 1..N are
# probes. select-probe activates one by copying its catalog slot into
# the active region. None of these overlap the bootable image (first
# ~272 MB), the eMMC backup (0x200000), or the debug log (0x400000).
PROBE_ACTIVE_LBA=1048576     # 0x100000 — PROBE_REGION_LBA in the kernel
PROBE_CATALOG_LBA=1572864    # 0x180000 — start of the catalog
PROBE_SLOT_BLOCKS=32         # 16 KB per slot (== PROBE_BLOCKS in the kernel)
PROBE_DEFAULT=health-check   # the probe flash-sd activates by default
# }}}

# {{{ probe_auto_priority() — should this probe run in the auto sweep?
# A probe in the unattended "run all" sweep declares an "#AUTO [N]"
# marker line; N is its run-order priority (lower runs first, default
# 50). Echoes the number, or "no" if there is no marker. Ordering lets
# the safe read-only checks run before the ones that change hardware
# state.
probe_auto_priority() {
    local line n
    line="$(grep -m1 -E '^#AUTO' "$1" || true)"
    [ -z "$line" ] && { echo "no"; return; }
    n="$(echo "$line" | awk '{print $2}')"
    if [ -n "$n" ] && [ "$n" -eq "$n" ] 2>/dev/null; then echo "$n"; else echo 50; fi
}
# }}}

# {{{ write_runall_marker() — a 16-byte "SPRA" active-region header
# Tells the kernel to run the whole catalog sweep instead of a single
# probe. No script text follows; the kernel reads the catalog itself.
write_runall_marker() {
    printf 'SPRA' > "$1"
    printf '\000\000\000\000\000\000\000\000\000\000\000\000' >> "$1"
}
# }}}

# {{{ probe_needs_writes() — does this probe contain register writes?
# A probe that pokes registers (a W line) must have the header's
# writes-enabled bit set, or the kernel ignores its W commands. Rather
# than make a tech remember a --writes flag, each such probe declares
# a "#WRITES" marker line in its own text, and the tooling reads it
# here. Returns 0 (true) if the marker is present.
probe_needs_writes() {
    grep -qE '^#WRITES\b' "$1"
}
# }}}

# {{{ build_probe_payload() — header + script text into an output file
# Header layout (matches src/019-probe-engine.c):
#   [0:4]   magic  "SPRB"
#   [4:8]   flags  (u32 LE) — bit 0 = writes enabled
#   [8:12]  length (u32 LE) — bytes of script text
#   [12:16] reserved
#   [16:]   script text
build_probe_payload() {
    local script_file="$1" writes="$2" out_file="$3"
    local len flags
    len="$(stat -c%s "$script_file")"
    flags=0
    [ "$writes" = "yes" ] && flags=1

    printf 'SPRB' > "$out_file"
    printf "$(printf '\\%03o' \
        $((flags & 0xff)) $(((flags >> 8) & 0xff)) \
        $(((flags >> 16) & 0xff)) $(((flags >> 24) & 0xff)))" >> "$out_file"
    printf "$(printf '\\%03o' \
        $((len & 0xff)) $(((len >> 8) & 0xff)) \
        $(((len >> 16) & 0xff)) $(((len >> 24) & 0xff)))" >> "$out_file"
    printf '\000\000\000\000' >> "$out_file"
    cat "$script_file" >> "$out_file"
}
# }}}
