#!/usr/bin/env bash
# fetch-patch-programs.sh — gather Blizzard's Warcraft III patch programs from public mirrors
#
# In plain terms: to rebuild the game data of each Warcraft III version (so a
# map plays with the numbers it was balanced for), the project reads each
# version's patch program. This script collects those programs into one
# folder beside the installs, from the list in wc3-installs/patch-sources.tsv
# (public mirrors only, never Blizzard's servers). Each file's checksum and
# origin are written to a record next to it, so every later step can say
# exactly which file it was built from. Files already present with a matching
# record are skipped, so running it again changes nothing.
#
# The downloaded programs are Blizzard's files: they live outside the
# repository, reached through the wc3-installs/patch-programs link, and are
# never committed.
#
# Usage:
#   scripts/fetch-patch-programs.sh [DIR] [options]
#
#   DIR              project root (default: the path below)
#   --only VERSION   fetch one version (both games, if both are listed)
#   --game GAME      fetch only "tft" or "roc"
#   --list           show each listed patch and whether it is present
#   --help
#
# Issue: issues/112b-game-version-layers-per-map.md

set -euo pipefail

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [[ $# -gt 0 && "$1" != --* ]]; then
    DIR="$1"
    shift
fi

SOURCES="$DIR/wc3-installs/patch-sources.tsv"
TARGET="$DIR/wc3-installs/patch-programs"
RECORD_NAME="sources.tsv"   # beside the downloads: saved-as, version, game, sha256, source, member, fetched-at

ONLY=""
GAME=""
LIST=0

# {{{ usage
usage() {
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
}
# }}}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --only) ONLY="$2"; shift 2 ;;
        --game) GAME="$2"; shift 2 ;;
        --list) LIST=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if [[ ! -d "$TARGET/" ]]; then
    echo "no $TARGET folder: create it as a link to a folder beside the installs, e.g." >&2
    echo "  mkdir -p /mnt/mtwo/games/warcraft-iii/patch-programs" >&2
    echo "  ln -s /mnt/mtwo/games/warcraft-iii/patch-programs $TARGET" >&2
    exit 1
fi
RECORD="$TARGET/$RECORD_NAME"
touch "$RECORD"

# {{{ recorded_sha
# The checksum the record holds for a saved file, or nothing.
recorded_sha() {
    awk -F '\t' -v f="$1" '$1 == f { sha = $4 } END { print sha }' "$RECORD"
}
# }}}

# {{{ fetch_one
# Brings one listed file into TARGET, then records it. A file whose checksum
# already matches its record is left alone; one that doesn't match is an
# error (it was changed or replaced by hand), never silently overwritten.
fetch_one() {
    local version="$1" game="$2" source="$3" member="$4" saved="$5"
    local path="$TARGET/$saved"
    local known
    known="$(recorded_sha "$saved")"
    if [[ -f "$path" && -n "$known" ]]; then
        local now
        now="$(sha256sum "$path" | cut -d' ' -f1)"
        if [[ "$now" == "$known" ]]; then
            echo "  present   $version $game  $saved"
            return 0
        fi
        echo "  MISMATCH  $version $game  $saved: its checksum differs from the record; move it aside and re-run" >&2
        return 1
    fi

    # A zip already downloaded this run serves its other rows too (the
    # patches bundle holds both games' 1.27b); the record still names the
    # mirror, not the local copy.
    local work
    if [[ "$member" != "-" && -n "${ZIP_CACHE[$source]:-}" ]]; then
        work="${ZIP_CACHE[$source]}"
    else
        work="$TARGET/.incoming-$saved"
        # Called as "fetch_one ... || FAILED=1", where bash ignores set -e, so
        # each step that can fail stops this file explicitly.
        case "$source" in
            file://*) cp "${source#file://}" "$work" || { echo "  FAILED    $version $game  copy from $source" >&2; return 1; } ;;
            *)        curl --fail --location --silent --show-error --retry 3 -o "$work" "$source" < /dev/null \
                          || { rm -f "$work"; echo "  FAILED    $version $game  download from $source" >&2; return 1; } ;;
        esac
    fi

    # A zip holds the program as one member; only that member is kept.
    if [[ "$member" != "-" ]]; then
        local unpacked="$TARGET/.unpacked-$saved"
        mkdir -p "$unpacked"
        unzip -q -o -j "$work" "$member" -d "$unpacked" < /dev/null \
            || { echo "  FAILED    $version $game  $member not in the zip from $source" >&2; return 1; }
        mv "$unpacked/$member" "$path" || return 1
        rmdir "$unpacked"
        ZIP_CACHE[$source]="$work"
    else
        mv "$work" "$path" || return 1
    fi

    local sha
    sha="$(sha256sum "$path" | cut -d' ' -f1)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$saved" "$version" "$game" "$sha" "$source" "$member" \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$RECORD"
    echo "  fetched   $version $game  $saved  $sha"
}
# }}}

declare -A ZIP_CACHE=()
FAILED=0
while IFS=$'\t' read -r version game source member saved; do
    [[ -z "$version" || "$version" == \#* ]] && continue
    [[ -n "$ONLY" && "$version" != "$ONLY" ]] && continue
    [[ -n "$GAME" && "$game" != "$GAME" ]] && continue
    if [[ $LIST -eq 1 ]]; then
        if [[ -f "$TARGET/$saved" ]]; then state="present"; else state="missing"; fi
        printf '  %-8s %-6s %-4s %s\n' "$state" "$version" "$game" "$saved"
        continue
    fi
    fetch_one "$version" "$game" "$source" "$member" "$saved" || FAILED=1
done < "$SOURCES"

for z in "${ZIP_CACHE[@]+"${ZIP_CACHE[@]}"}"; do
    rm -f "$z"
done

exit $FAILED
