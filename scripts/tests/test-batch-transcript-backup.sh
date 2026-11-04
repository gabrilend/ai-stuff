#!/usr/bin/env bash
# test-batch-transcript-backup.sh
# Checks batch-transcript-backup.sh (issue 009) against a pretend monorepo:
# two projects with conversations and one without, a stand-in
# backup-conversations that writes one transcript per conversation log, and
# a stand-in exporter that records each call.  Nothing real is read or
# written: HOME and the scripts folder both point into a scratch folder.
#
# What it pins:
#   - only project lines are read as projects (the "Discovering" log line
#     used to be read as one);
#   - -v N exports level N, a range exports each conversation once per
#     level even after earlier runs left level files beside the baseline;
#   - --since limits the run to conversations changed since the date;
#   - --commit commits llm-transcripts and nothing else that was staged;
#   - failures are shown and end in exit 1, an unknown project is an error,
#     bad option values are errors;
#   - a file count past 255 is reported as itself, not wrapped;
#   - -I: the menu picks projects and levels (needs `script`).
#
# Usage: bash test-batch-transcript-backup.sh [scripts-dir]

SCRIPTS_DIR="/home/ritz/programming/ai-stuff/scripts"
if [ -n "${1:-}" ]; then
    SCRIPTS_DIR="$1"
fi
SCRIPTS_DIR="$(cd "$SCRIPTS_DIR" && pwd)"
TOOL="$SCRIPTS_DIR/batch-transcript-backup.sh"

mkdir -p /tmp/claude-1000
T="$(mktemp -d /tmp/claude-1000/batch-backup.XXXXXX)"

pass=0; fail=0
check() { # check <label> <actual> <expected>
    if [ "$2" = "$3" ]; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: got [$2] want [$3]"; fi
}
has() { # has <label> <file> <fixed text>
    if grep -qF -- "$3" "$2"; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: [$3] not in output"; sed 's/^/        /' "$2" | tail -15; fi
}
lacks() { # lacks <label> <file> <fixed text>
    if ! grep -qF -- "$3" "$2"; then pass=$((pass+1)); echo "  ok   - $1"
    else fail=$((fail+1)); echo "  FAIL - $1: [$3] should not be in output"; fi
}

# {{{ build the pretend monorepo
# Encodes a path the way Claude names its project folders.
encode() { echo "$1" | sed 's|/|-|g'; }

build() {
    rm -rf "$T/mono" "$T/home"
    mkdir -p "$T/mono/scripts" "$T/mono/delta-version/scripts" "$T/home/.claude/projects"
    ln -s "$SCRIPTS_DIR/libs" "$T/mono/scripts/libs"
    local p
    for p in alpha beta gamma; do mkdir -p "$T/mono/$p"; done

    cat > "$T/mono/delta-version/scripts/list-projects.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$T/mono/alpha" "$T/mono/beta" "$T/mono/gamma"
EOF

    # One transcript per conversation log, named after the log.
    cat > "$T/mono/scripts/backup-conversations" <<'EOF'
#!/usr/bin/env bash
project="$1"
name="$(basename "$project")"
if [ "${FAIL_BACKUP:-}" = "$name" ]; then echo "disk full in $name"; exit 4; fi
logs="$HOME/.claude/projects/$(echo "$project" | sed 's|/|-|g')"
mkdir -p "$project/llm-transcripts"
for f in "$logs"/*.jsonl; do
    [ -e "$f" ] || continue
    id="$(basename "$f" .jsonl)"
    printf '# Conversation Summary: %s\nbaseline\n' "$id" > "$project/llm-transcripts/$id.md"
done
EOF

    # Records each call; prints a level transcript, nothing, or fails.
    cat > "$T/mono/scripts/claude-conversation-exporter.sh" <<EOF
#!/usr/bin/env bash
level="\${1#-v}"
echo "\$(basename "\$2") \$3 v\$level" >> "$T/exporter.log"
# SLOW: mark the start and end of each call, a second apart, so a test can
# see two levels running at once.
if [ -n "\${SLOW:-}" ]; then echo "start \$level" >> "$T/timeline.log"; sleep 1; echo "end \$level" >> "$T/timeline.log"; fi
if [ "\${FAIL_LEVEL:-}" = "\$level" ]; then echo "exporter: level \$level broke on \$3" >&2; exit 3; fi
if [ "\${EMPTY_LEVEL:-}" = "\$level" ]; then exit 0; fi
printf '# Conversation Summary: %s\nlevel %s\n' "\$3" "\$level"
EOF
    chmod +x "$T/mono/delta-version/scripts/list-projects.sh" \
        "$T/mono/scripts/backup-conversations" "$T/mono/scripts/claude-conversation-exporter.sh"

    local alpha_logs beta_logs
    alpha_logs="$T/home/.claude/projects/$(encode "$T/mono/alpha")"
    beta_logs="$T/home/.claude/projects/$(encode "$T/mono/beta")"
    mkdir -p "$alpha_logs" "$beta_logs"
    echo '{}' > "$alpha_logs/a1.jsonl"
    echo '{}' > "$alpha_logs/a2.jsonl"
    echo '{}' > "$beta_logs/b1.jsonl"
    rm -f "$T/exporter.log" "$T/timeline.log"
}

# run <name> <args...>: runs the tool, output in $T/<name>.out, status in $T/<name>.rc
run() {
    local name="$1"; shift
    ( cd "$T" && HOME="$T/home" DIR="$T/mono/scripts" bash "$TOOL" "$@" ) > "$T/$name.out" 2>&1
    echo $? > "$T/$name.rc"
}
rc() { cat "$T/$1.rc"; }
calls() { [ -f "$T/exporter.log" ] && wc -l < "$T/exporter.log" | tr -d ' ' || echo 0; }
# }}}

echo "baseline only"
build
run all --all
check "--all exits 0" "$(rc all)" "0"
has "only the two projects with conversations are found" "$T/all.out" "Found 2 projects with conversations"
check "alpha has its two transcripts" "$(ls "$T/mono/alpha/llm-transcripts" | tr '\n' ' ')" "a1.md a2.md "
check "beta has its one" "$(ls "$T/mono/beta/llm-transcripts" | tr '\n' ' ')" "b1.md "
check "no level exports without a level option" "$(calls)" "0"
has "summary counts the conversations" "$T/all.out" "Total conversations: 3"

echo "one level, by name"
build
run one -v 4 alpha
check "-v 4 alpha exits 0" "$(rc one)" "0"
check "alpha gains level-4 files" "$(ls "$T/mono/alpha/llm-transcripts" | tr '\n' ' ')" \
    "a1-v4-complete.md a1.md a2-v4-complete.md a2.md "
check "beta is left alone" "$(ls "$T/mono/beta/llm-transcripts" 2>/dev/null | wc -l | tr -d ' ')" "0"

echo "a range, run twice"
build
run range1 --verbosity-range 2-3 alpha
run range2 --verbosity-range 2-3 alpha
check "first run exports 2 conversations x 2 levels" "$(head -4 "$T/exporter.log" | wc -l | tr -d ' ')" "4"
check "second run exports the same 4, not one per level file" "$(calls)" "8"
check "second run exits 0" "$(rc range2)" "0"
has "summary counts transcripts plus level files" "$T/range2.out" "Transcripts in place plus level files written: 6"

echo "--since"
build
touch -d 2020-01-01 "$T/home/.claude/projects/$(encode "$T/mono/alpha")/a1.jsonl"
touch -d 2020-01-01 "$T/home/.claude/projects/$(encode "$T/mono/beta")/b1.jsonl"
run since --since 2025-01-01 --all -v 1
check "--since exits 0" "$(rc since)" "0"
has "a project with nothing new is skipped" "$T/since.out" "Found 1 projects with conversations"
check "only the changed conversation is exported" "$(cut -d' ' -f2,3 "$T/exporter.log" | tr '\n' ' ')" "a2 v1 "
run since-none --since 2030-01-01 --all
check "nothing changed: exits 0" "$(rc since-none)" "0"
has "nothing changed: says so" "$T/since-none.out" "No projects with conversations changed since 2030-01-01"
run since-bad --since "not a date" --all
check "a date that does not read is an error" "$(rc since-bad)" "1"

echo "errors"
build
run unknown alpha delta
check "an unknown project is an error" "$(rc unknown)" "1"
has "it is named" "$T/unknown.out" "No conversations to back up for: delta"
check "and nothing was done" "$(ls "$T/mono/alpha" | wc -l | tr -d ' ')" "0"
run badrange --verbosity-range 4-2 --all
check "a backwards range is an error" "$(rc badrange)" "1"
run badlevel -v 9 --all
check "level 9 is an error" "$(rc badlevel)" "1"
run novalue --all -v
check "-v with no value is an error" "$(rc novalue)" "1"
FAIL_BACKUP=beta run backupfail --all
check "a failed backup-conversations ends in exit 1" "$(rc backupfail)" "1"
has "its messages are shown" "$T/backupfail.out" "disk full in beta"
has "the other project still ran" "$T/backupfail.out" "Processing: alpha"
build
FAIL_LEVEL=3 run exportfail -v 3 alpha
check "a failed export ends in exit 1" "$(rc exportfail)" "1"
has "the exporter's message is shown" "$T/exportfail.out" "exporter: level 3 broke on a1"
check "no file is left for a failed export" "$(ls "$T/mono/alpha/llm-transcripts" | grep -c v3)" "0"
build
EMPTY_LEVEL=0 run exportempty -v 0 alpha
check "an empty export is a warning, not a failure" "$(rc exportempty)" "0"
has "it is reported" "$T/exportempty.out" "was empty; no file kept"

echo "--commit"
build
git -C "$T/mono" init -q
git -C "$T/mono" config user.email test@example.invalid
git -C "$T/mono" config user.name test
echo keep > "$T/mono/staged-elsewhere.txt"
git -C "$T/mono" add staged-elsewhere.txt
run commit --all --commit
check "--commit exits 0" "$(rc commit)" "0"
check "one commit per project" "$(git -C "$T/mono" rev-list --count HEAD 2>/dev/null)" "2"
check "the commits hold only llm-transcripts" \
    "$(git -C "$T/mono" log --name-only --format= | grep -v '^$' | grep -vc '/llm-transcripts/')" "0"
check "what was staged elsewhere is still staged, not committed" \
    "$(git -C "$T/mono" diff --cached --name-only)" "staged-elsewhere.txt"
run commit2 --all --commit
has "a second run has nothing new" "$T/commit2.out" "Nothing new to commit in alpha"
check "and makes no commit" "$(git -C "$T/mono" rev-list --count HEAD)" "2"

echo "--output-dir, --metadata (issue 056)"
build
run outdir --output-dir "$T/out" --metadata -v 2 alpha
check "--output-dir exits 0" "$(rc outdir)" "0"
check "level files go to <output-dir>/<project>" "$(ls "$T/out/alpha" | tr '\n' ' ')" \
    "a1-v2-standard.md a1.exports.txt a2-v2-standard.md a2.exports.txt "
check "baselines stay in the project" "$(ls "$T/mono/alpha/llm-transcripts" | tr '\n' ' ')" "a1.md a2.md "
check "the metadata line names the file and its size" "$(cut -f1,2 "$T/out/alpha/a1.exports.txt")" \
    "a1-v2-standard.md	$(stat -c %s "$T/out/alpha/a1-v2-standard.md")"
check "and when it was exported" "$(cut -f3 "$T/out/alpha/a1.exports.txt" | grep -c '^20[0-9][0-9]-')" "1"
build
FAIL_LEVEL=3 run metafail --output-dir "$T/out2" --metadata --verbosity-range 2-3 alpha
check "a failed level is not in the metadata" "$(cut -f1 "$T/out2/alpha/a1.exports.txt" | tr '\n' ' ')" "a1-v2-standard.md "
run nometa --output-dir "$T/out3" -v 1 alpha
check "no metadata file without --metadata" "$(ls "$T/out3/alpha" | grep -c exports)" "0"

echo "--combined (issue 056)"
build
mkdir -p "$T/mono/llm-transcripts"
run combined --combined -v 1 --all
check "--combined exits 0" "$(rc combined)" "0"
C="$T/mono/llm-transcripts/combined-$(date +%F).md"
check "the combined file goes to the monorepo's llm-transcripts" "$([ -f "$C" ] && echo yes)" "yes"
check "it has a part per project" "$(grep -c '^## ' "$C")" "2"
check "and every baseline transcript" "$(grep -c '^baseline$' "$C")" "3"
check "and no level export" "$(grep -c '^level ' "$C")" "0"
build
touch -d 2020-01-01 "$T/home/.claude/projects/$(encode "$T/mono/alpha")/a1.jsonl"
run combsince --combined --output-dir "$T/cout" --since 2025-01-01 --all
check "with --output-dir it goes there, and --since keeps only the changed ones" \
    "$(grep '^### ' "$T/cout/combined-$(date +%F).md" | tr '\n' ' ')" "### a2.md ### b1.md "
run combdry --combined --dry-run --all
has "a dry run says where it would go" "$T/combdry.out" "Would join the baseline transcripts into:"

echo "--parallel (issue 056)"
build
SLOW=1 run par --parallel 3 --verbosity-range 0-2 beta
check "--parallel exits 0" "$(rc par)" "0"
check "all levels are written" "$(ls "$T/mono/beta/llm-transcripts" | wc -l | tr -d ' ')" "4"
check "levels ran at the same time (two starts before any end)" "$(head -2 "$T/timeline.log" | grep -c '^start')" "2"
build
SLOW=1 run seq --verbosity-range 0-1 beta
check "without --parallel, one at a time" "$(head -2 "$T/timeline.log" | tr '\n' ' ')" "start 0 end 0 "
build
FAIL_LEVEL=1 run parfail --parallel 4 --verbosity-range 0-3 beta
check "a failed level in parallel ends in exit 1" "$(rc parfail)" "1"
has "its messages are shown, with the level" "$T/parfail.out" "level 1: exporter: level 1 broke on b1"
check "the other levels are kept" "$(ls "$T/mono/beta/llm-transcripts" | tr '\n' ' ')" \
    "b1-v0-minimal.md b1-v2-standard.md b1-v3-verbose.md b1.md "
run badpar --parallel 0 --all
check "--parallel 0 is an error" "$(rc badpar)" "1"

echo "--commit with --output-dir and --combined (issue 056)"
build
git -C "$T/mono" init -q
git -C "$T/mono" config user.email test@example.invalid
git -C "$T/mono" config user.name test
run commitout --commit --output-dir "$T/mono/exports" --combined -v 0 alpha
check "commit run exits 0" "$(rc commitout)" "0"
check "baselines, exports and the combined file are all committed" \
    "$(git -C "$T/mono" log --name-only --format= | grep -v '^$' | sed 's|/[^/]*$||' | sort -u | tr '\n' ' ')" \
    "alpha/llm-transcripts exports exports/alpha "
check "nothing it wrote is left uncommitted" \
    "$(git -C "$T/mono" status --porcelain -uall -- exports alpha/llm-transcripts | wc -l | tr -d ' ')" "0"

echo "a count past 255"
build
for i in $(seq 1 300); do echo '{}' > "$T/home/.claude/projects/$(encode "$T/mono/alpha")/c$i.jsonl"; done
run many alpha
check "300 conversations exit 0" "$(rc many)" "0"
has "and are counted as 302" "$T/many.out" "Transcripts in place plus level files written: 302"

# {{{ the menu (-I), typed into a pretend terminal
# run_menu <name> <tool args> -- <keys...>
run_menu() {
    local name="$1"; shift
    local args=()
    while [ "$1" != "--" ]; do args+=("$1"); shift; done
    shift
    {
        sleep 2
        for key in "$@"; do printf '%s' "$key"; sleep 1; done
        sleep 2
    } | timeout 30 script -qfc "stty rows 40 cols 120; cd '$T' && HOME='$T/home' DIR='$T/mono/scripts' bash '$TOOL' ${args[*]} > '$T/$name.out' 2>&1; echo \$? > '$T/$name.rc'" "$T/$name.log" >/dev/null 2>&1
}

if command -v script >/dev/null && command -v luajit >/dev/null; then
    echo "the menu"
    build
    # Down to alpha, tick it; r jumps to Run, r again runs.
    run_menu menu-pick -I --dry-run -- j ' ' r r
    check "menu run exits 0" "$(rc menu-pick)" "0"
    has "the ticked project is processed" "$T/menu-pick.out" "Processing: alpha"
    lacks "the unticked one is not" "$T/menu-pick.out" "Processing: beta"
    has "the dry run from the command line holds" "$T/menu-pick.out" "DRY RUN MODE"

    build
    run_menu menu-quit -I -- q
    check "quitting the menu exits 0" "$(rc menu-quit)" "0"
    has "and says nothing was done" "$T/menu-quit.out" "Menu closed without running; nothing done."
    check "nothing was backed up" "$(ls "$T/mono/alpha" | wc -l | tr -d ' ')" "0"

    build
    # Tick All projects; down past alpha, beta and "Baseline only" to
    # "Also level 0", choose it; then run.
    run_menu menu-all -I -- ' ' j j j j ' ' r r
    check "menu with All projects exits 0" "$(rc menu-all)" "0"
    has "both projects run" "$T/menu-all.out" "Processing: beta"
    check "the level chosen in the menu is exported" "$(ls "$T/mono/beta/llm-transcripts" | tr '\n' ' ')" "b1-v0-minimal.md b1.md "
else
    echo "the menu: skipped here, needs script and luajit"
fi
# }}}

[ -n "${KEEP:-}" ] && echo "kept $T" || rm -rf "$T"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
