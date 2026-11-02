#!/bin/bash
# test-process-template.sh - proves the keyword markup engine (libs/kml.lua,
# through process-template.lua) fills templates the way the specification
# says, and refuses what it must.
#
# In general terms: builds a pretend delta-version folder in RAM with a small
# keyword configuration of its own (commands that echo, fail, sleep, count
# how often they ran, and print where they ran), a pretend project with its
# own configuration layered on top, and templates that use each feature; then
# fills them and checks the output: values and parameters in place, escapes
# kept, every kind of failure handled by each error mode, a parameter that
# could inject a shell command refused without running anything, each
# distinct command run once, commands run in the project's folder, the
# engine's own keywords not redefinable, and the real configuration's
# keywords all usable.
# Exercises the success criteria of issue 017.
#
# Usage: test-process-template.sh [monorepo]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ -n "${1:-}" ] && DIR="$1"

TOOL="$DIR/delta-version/scripts/process-template.lua"
SCRATCH="$DIR/delta-version/tmp/shared-memory/process-template-test"
DV="$SCRATCH/delta-version"
PROJECT="$SCRATCH/project"

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

# -- {{{ yes_if
function yes_if() {
    if "$@" >/dev/null 2>&1; then echo yes; else echo no; fi
}
# }}}

# -- {{{ same
function same() {
    [ "$1" = "$2" ]
}
# }}}

# -- {{{ contains
function contains() {
    # True when the first argument holds the second as plain text.
    grep -qF -- "$2" <<< "$1"
}
# }}}

# -- {{{ lacks
function lacks() {
    ! contains "$1" "$2"
}
# }}}

# -- {{{ build_fixture
function build_fixture() {
    source "$DIR/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$DIR/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$DV/config" "$PROJECT/config" "$PROJECT/src"

    cat > "$DV/config/ticket-keywords.conf" <<EOF
# a test configuration
[metadata]
version=1.0
error_mode=placeholder
timeout=10

[data_keywords]
greeting=echo hello
where=pwd
two_lines=printf 'one\ntwo\n'
pair=echo 'PARAM1+PARAM2'
counted=echo run >> "$SCRATCH/runs"; echo counted
failing=echo 'it broke' >&2; exit 3
slow=sleep 5; echo late
template_name=echo hacked
overridden=echo from-default
custom_wins=echo from-data-section

[custom_keywords]
custom_wins=echo from-custom-section
EOF
    cat > "$PROJECT/config/ticket-keywords.conf" <<'EOF'
[data_keywords]
overridden=echo from-project
project_only=echo only-here
EOF
    printf 'x\n' > "$PROJECT/src/a.lua"
    printf 'y\n' > "$PROJECT/src/b.lua"
}
# }}}

# -- {{{ fill
function fill() {
    # Fills the template text given as $1 in the project; output in OUT,
    # errors in ERR, status in STATUS.
    local text="$1"; shift
    printf '%s' "$text" > "$SCRATCH/template.md"
    OUT=$(luajit "$TOOL" "$SCRATCH/template.md" "$PROJECT" --dir="$DV" "$@" 2>"$SCRATCH/err")
    STATUS=$?
    ERR=$(cat "$SCRATCH/err")
}
# }}}

# -- {{{ run_tests
function run_tests() {
    echo "filling"
    fill 'Say ][greeting[] from ][where[].'
    check "a keyword is replaced by its command's output" \
        "$(yes_if same "$OUT" "Say hello from $(cd "$PROJECT" && pwd).")"
    check "exit 0"                                          "$(yes_if same "$STATUS" 0)"
    fill '][pair[left,right/x.y-z_1][]'
    check "parameters fill PARAM1 and PARAM2"              "$(yes_if same "$OUT" "left+right/x.y-z_1")"
    fill '[][two_lines[]]'
    check "a multi-line value is kept, its last newline dropped" \
        "$(yes_if same "$OUT" "$(printf '[one\ntwo]')")"
    fill 'A ][ name ][ marker, a][b, and ][ alone.'
    check "a \"][\" not followed by a name is plain text" \
        "$(yes_if same "$OUT" 'A ][ name ][ marker, a][b, and ][ alone.')"
    fill 'Literal \][greeting[] and \][Not_Valid[] and \\][greeting[].'
    check "\\][ keeps a placeholder as text; \\\\][ is a backslash and a value" \
        "$(yes_if same "$OUT" 'Literal ][greeting[] and ][Not_Valid[] and \hello.')"

    echo "the engine's own keywords"
    fill '][kml_version[] ][template_name[] ][ticket_id[]' --ticket-id=T-42
    check "kml_version, template_name and ticket_id"        "$(yes_if same "$OUT" "1.0 template.md T-42")"
    check "a configuration cannot redefine template_name"   "$(yes_if lacks "$OUT" hacked)"
    fill '][generation_date[]'
    check "generation_date is a timestamp"                  "$(yes_if grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8}$' <<< "$OUT")"
    fill '][ticket_id[]'
    check "a ticket id is made when none is given"          "$(yes_if grep -qE '^T-[0-9]{8}-[0-9]{6}-[0-9a-f]{4}$' <<< "$OUT")"
    fill '][error[] ][debug[]'
    check "error and debug are reserved"                    "$(yes_if same "$OUT" "[ERROR: error] [ERROR: debug]")"

    echo "configuration"
    fill '][overridden[] ][project_only[] ][greeting[] ][custom_wins[]'
    check "the project's configuration is layered over delta-version's" \
        "$(yes_if same "$OUT" "from-project only-here hello from-custom-section")"
    fill '][overridden[]' --config="$DV/config/ticket-keywords.conf"
    check "--config uses that file alone"                   "$(yes_if same "$OUT" "from-default")"

    echo "failures, in each error mode"
    local bad='a ][nosuch[] b ][Bad_Name[] c ][pair[one][] d ][failing[] e'
    fill "$bad"
    check "placeholder (the configuration's mode) marks each" \
        "$(yes_if same "$OUT" "a [ERROR: nosuch] b [ERROR: Bad_Name] c [ERROR: pair] d [ERROR: failing] e")"
    check "and still exits 0"                               "$(yes_if same "$STATUS" 0)"
    check "each failure is named on standard error"         "$(yes_if same "$(wc -l <<< "$ERR")" 4)"
    check "an unknown keyword says so"                      "$(yes_if contains "$ERR" "][nosuch[]: unknown keyword")"
    check "a bad name says so"                              "$(yes_if contains "$ERR" "invalid keyword name")"
    check "a wrong parameter count says so"                 "$(yes_if contains "$ERR" "expects 2 parameters, got 1")"
    fill "$bad" --error-mode=remove
    check "remove leaves nothing in their place"            "$(yes_if same "$OUT" "a  b  c  d  e")"
    fill "$bad" --error-mode=verbose
    check "verbose says why, with the command's own complaint" \
        "$(yes_if contains "$OUT" "[ERROR: failing - exit 3: it broke]")"
    fill "$bad" --error-mode=fail --output="$SCRATCH/out.md"
    check "fail exits 1"                                    "$(yes_if same "$STATUS" 1)"
    check "and writes nothing"                              "$(yes_if [ ! -e "$SCRATCH/out.md" ])"
    fill '][slow[]' --timeout=1 --error-mode=verbose
    check "a command past its time limit is stopped"        "$(yes_if same "$OUT" "[ERROR: slow - timed out after 1s]")"
    fill '][pair[x;touch_pwned,y][] ][pair[a b,c][] ][pair[$(touch_pwned),c][]'
    check "a parameter outside the allowed characters is refused" \
        "$(yes_if same "$OUT" "[ERROR: pair] [ERROR: pair] [ERROR: pair]")"
    check "and nothing ran"                                 "$(yes_if [ ! -e "$PROJECT/touch_pwned" ])"
    fill '][pair[a,b,c,d,e,f][]'
    check "more than five parameters is refused"            "$(yes_if contains "$ERR" "more than 5 parameters")"

    echo "running each command once"
    rm -f "$SCRATCH/runs"
    fill '][counted[] ][counted[] ][counted[]'
    check "a keyword used three times runs once"            "$(yes_if same "$(wc -l < "$SCRATCH/runs")" 1)"
    check "and fills all three"                             "$(yes_if same "$OUT" "counted counted counted")"

    echo "checking and listing"
    fill '][greeting[] ][nosuch[] \][nosuch[]' --check
    check "--check marks the usable and the not"            "$(yes_if contains "$OUT" "ok   ][greeting[]")"
    check "naming the problem"                              "$(yes_if contains "$OUT" "bad  ][nosuch[]  unknown keyword")"
    check "skipping escaped placeholders"                   "$(yes_if same "$(grep -c nosuch <<< "$OUT")" 1)"
    check "and exits 1"                                     "$(yes_if same "$STATUS" 1)"
    OUT=$(luajit "$TOOL" --list "$PROJECT" --dir="$DV")
    check "--list shows each keyword with its parameters"   "$(yes_if contains "$OUT" "][pair[p1,p2][]")"
    fill 'x' --error-mode=loud
    check "an unknown error mode is refused with exit 2"    "$(yes_if same "$STATUS" 2)"

    echo "the real configuration"
    cp "$DIR/delta-version/config/ticket-keywords.conf" "$SCRATCH/real.conf"
    local example
    example=$(sed -n '/^### Input Template/,/^### Output/p' "$DIR/delta-version/docs/keyword-markup-language-spec.md" \
              | sed -n '/^```markdown$/,/^```$/p' | sed '1d;$d')
    fill "$example" --config="$SCRATCH/real.conf" --check
    check "the specification's example template uses only usable keywords" \
        "$(yes_if same "$STATUS" 0)"
    fill "$example" --config="$SCRATCH/real.conf" --error-mode=fail
    check "and fills without a failure"                     "$(yes_if same "$STATUS" 0)"
    check "with the project's name in its title"            "$(yes_if contains "$OUT" "# Project Report: project")"
    fill '][file_list[lua,src][]' --config="$SCRATCH/real.conf"
    check "file_list joins names with a comma and space, none trailing" \
        "$(yes_if grep -qxE 'a\.lua, b\.lua|b\.lua, a\.lua' <<< "$OUT")"
}
# }}}

build_fixture
run_tests
rm -rf "$SCRATCH"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
