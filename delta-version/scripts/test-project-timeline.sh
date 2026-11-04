#!/bin/bash
# test-project-timeline.sh - proves the project timeline reads history
# correctly and draws every layout.
#
# In general terms: it builds a tiny pretend repository in a scratch folder
# with three projects and a handful of commits at chosen dates, plus saved
# conversations with dated names. Then it runs the timeline tools on it and
# checks that each project's birthday and working days come out exactly as
# planted: a commit that touches too many projects counts as a sweep, a
# conversation spanning several days lights each of them, a nested project
# gets its own files and not its shelf's. Finally it paints all four layouts
# and builds the page, and checks the pictures are real PNGs of sensible size.
# Exercises issue 067.

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"
if [ "${1:-}" = "--help" ]; then
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
    echo "Usage: test-project-timeline.sh [--dir MONOREPO]"
    exit 0
fi

SCRIPTS="$DIR/delta-version/scripts"
# Copies live in guaranteed RAM, through the project's tmp/ door.
SCRATCH="$DIR/delta-version/tmp/shared-memory/project-timeline-test"
REPO="$SCRATCH/repo"
FIXTURE_DV="$REPO/delta-version"

PASS=0
FAIL=0

# -- {{{ check
function check() {
    # One line per assertion; failures keep going so a run reports everything.
    local label="$1" ok="$2"
    if [ "$ok" = "yes" ]; then
        echo "  ok   - $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL - $label"
        FAIL=$((FAIL + 1))
    fi
}
# }}}

# -- {{{ commit_at
function commit_at() {
    # A commit with a chosen author date, so birthdays are known in advance.
    local date="$1" message="$2"
    git -C "$REPO" add -A
    GIT_AUTHOR_DATE="$date 12:00:00" GIT_COMMITTER_DATE="$date 12:00:00" \
        git -C "$REPO" -c user.name=test -c user.email=test@test commit -q -m "$message"
}
# }}}

# -- {{{ build_fixture
function build_fixture() {
    # A reboot empties RAM and leaves the tmp/ symlink pointing at nothing;
    # the shared library rebuilds the rooms behind it before anything writes.
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$FIXTURE_DV/scripts" "$FIXTURE_DV/assets"
    cp "$SCRIPTS"/census-projects.lua "$SCRIPTS"/project-timeline-*.lua "$SCRIPTS"/project-timeline-page.html "$FIXTURE_DV/scripts/"
    cp "$DIR/delta-version/assets/project-focus.lua" "$FIXTURE_DV/assets/"
    echo "the tool's own home" > "$FIXTURE_DV/README.md"
    git -C "$REPO" init -q
    # the tool's own folder arrives first and alone, so it never shares a
    # commit with alpha (sharing one would make that commit a sweep)
    commit_at 2026-01-01 "the tool arrives"

    # alpha: born by commit on 2026-01-05, worked again on 2026-01-07
    mkdir -p "$REPO/alpha/src"
    echo "one" > "$REPO/alpha/src/main.lua"
    commit_at 2026-01-05 "alpha begins"
    echo "two" >> "$REPO/alpha/src/main.lua"
    commit_at 2026-01-07 "alpha grows"

    # games/beta: a nested project; born by conversation (2026-01-02,
    # earlier than any commit), the conversation runs through 2026-01-04
    mkdir -p "$REPO/games/beta/llm-transcripts"
    echo "beta" > "$REPO/games/beta/README.md"
    echo "talk" > "$REPO/games/beta/llm-transcripts/jan-2-26-through-jan-4-26.md"
    echo "talk" > "$REPO/games/beta/llm-transcripts/jan-9-26_agent-1.md"
    echo "notes" > "$REPO/games/beta/llm-transcripts/robot-analytics.md"
    commit_at 2026-01-06 "beta arrives"

    # a sweep touching every project on 2026-01-08; with --sweep=1 it is not work
    echo "x" > "$REPO/alpha/.gitignore"
    echo "x" > "$REPO/games/beta/.gitignore"
    echo "x" > "$FIXTURE_DV/.gitignore"
    commit_at 2026-01-08 "sweep everything"
}
# }}}

# -- {{{ field
function field() {
    # One project's value for a field, read through the same JSON library the
    # PNG drawer uses, printed as text (lists joined by commas).
    local project="$1" key="$2"
    # the script comes in on standard input ("-") because "luajit -e" leaves
    # the argument list empty
    luajit - "$SCRATCH/timeline.json" "$project" "$key" <<'LUA'
package.path = "/home/ritz/programming/ai-stuff/libs/lua/?.lua;" .. package.path
local data = require("dkjson").decode(io.open(arg[1]):read("*a"))
for _, p in ipairs(data.projects) do
    if p.name == arg[2] then
        local v = p[arg[3]]
        print(type(v) == "table" and table.concat(v, ",") or tostring(v))
    end
end
LUA
}
# }}}

# -- {{{ test_gather
function test_gather() {
    luajit "$FIXTURE_DV/scripts/project-timeline-gather.lua" --dir="$FIXTURE_DV" --sweep=1 \
        --today=2026-01-10 --out="$SCRATCH/timeline.json" > "$SCRATCH/gather.log"
    check "gatherer exits cleanly" "$([ $? -eq 0 ] && echo yes || echo no)"
    check "alpha is born on its first commit" "$([ "$(field alpha first_day)" = 2026-01-05 ] && echo yes || echo no)"
    check "alpha's commit days are its two own commits" \
        "$([ "$(field alpha commit_days)" = 2026-01-05,2026-01-07 ] && echo yes || echo no)"
    check "the many-project commit is a sweep, not work" \
        "$([ "$(field alpha sweep_days)" = 2026-01-08 ] && echo yes || echo no)"
    check "a nested project is born on its earliest conversation" \
        "$([ "$(field games/beta first_day)" = 2026-01-02 ] && echo yes || echo no)"
    check "a through-range lights every day; an agent suffix is still a date" \
        "$([ "$(field games/beta transcript_days)" = 2026-01-02,2026-01-03,2026-01-04,2026-01-09 ] && echo yes || echo no)"
    check "the shelf 'games' is not given the nested project's commits" \
        "$([ -z "$(field games first_day)" ] && echo yes || echo no)"
    check "a transcript name without a date is listed, not dropped" \
        "$(grep -q 'robot-analytics.md' "$SCRATCH/timeline.json" && echo yes || echo no)"
    check "birth order: delta-version, then games/beta, then alpha" \
        "$([ "$(grep -o '"name": "[^"]*"' "$SCRATCH/timeline.json" | head -3 | tr '\n' ' ')" = '"name": "delta-version" "name": "games/beta" "name": "alpha" ' ] && echo yes || echo no)"
    luajit "$FIXTURE_DV/scripts/project-timeline-gather.lua" --dir="$FIXTURE_DV" --bogus > /dev/null 2>&1
    check "an unknown argument is refused" "$([ $? -ne 0 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_pictures
function test_pictures() {
    local x_mode y_mode picture size
    for x_mode in order time; do
        for y_mode in age calendar; do
            picture="$SCRATCH/timeline-$x_mode-$y_mode.png"
            luajit "$FIXTURE_DV/scripts/project-timeline-png.lua" --in="$SCRATCH/timeline.json" \
                --out="$picture" --x="$x_mode" --y="$y_mode" > /dev/null
            size=$(magick identify -format '%m %w %h' "$picture")
            check "x=$x_mode y=$y_mode paints a PNG ImageMagick can read ($size)" \
                "$(echo "$size" | grep -q '^PNG [0-9]* [0-9]*$' && echo yes || echo no)"
        done
    done
    # nine days span (2026-01-02 to 2026-01-10) at 2 pixels a day: the picture
    # must be taller than the plot itself and wider than three columns
    size=$(magick identify -format '%w %h' "$SCRATCH/timeline-order-age.png")
    check "the default picture is big enough to hold three columns" \
        "$([ "${size% *}" -gt 135 ] && [ "${size#* }" -gt 18 ] && echo yes || echo no)"
    luajit "$FIXTURE_DV/scripts/project-timeline-png.lua" --in="$SCRATCH/timeline.json" \
        --out="$SCRATCH/bad.png" --sources=commits > /dev/null 2>&1
    check "an unknown source name is refused" "$([ $? -ne 0 ] && echo yes || echo no)"
}
# }}}

# -- {{{ test_page
function test_page() {
    luajit "$FIXTURE_DV/scripts/project-timeline-page.lua" --dir="$FIXTURE_DV" \
        --in="$SCRATCH/timeline.json" --out="$SCRATCH/page.html" > /dev/null
    check "page builder exits cleanly" "$([ $? -eq 0 ] && echo yes || echo no)"
    check "the page carries the data" "$(grep -q '"games/beta"' "$SCRATCH/page.html" && echo yes || echo no)"
    check "the data marker was replaced" "$(grep -q 'TIMELINE_DATA\*/' "$SCRATCH/page.html" && echo no || echo yes)"
    check "the page says what made it" "$(grep -q 'made by delta-version/scripts/project-timeline-page.lua' "$SCRATCH/page.html" && echo yes || echo no)"
    # the page's script must at least parse; node checks the syntax only
    sed -n '/^<script>$/,/^<\/script>$/p' "$SCRATCH/page.html" | sed '1d;$d' > "$SCRATCH/page-script.js"
    node --check "$SCRATCH/page-script.js"
    check "the page's script parses" "$([ $? -eq 0 ] && echo yes || echo no)"
}
# }}}

echo "project timeline"
build_fixture
test_gather
test_pictures
test_page
echo "passed $PASS, failed $FAIL"
[ "$FAIL" -eq 0 ]
