#!/bin/bash

# run.sh - Main orchestrator for neocities-modernization pipeline
#
# Runs the complete poem processing pipeline from input files to generated HTML.
# Supports selective stage execution via CLI flags, with stages running in
# pipeline order regardless of argument order.
#
# The full pipeline has 10 stages:
#   1. Update Words     - Sync input files from words repository
#   2. Extract          - Extract content from backup archives
#   3. Parse            - Generate poems.json from sources
#   4. Validate         - Validate poem data
#   5. Catalog Images   - Generate image-catalog.json
# Durations are deliberately absent from this list. Every stage's wall-clock is
# measured and recorded to .stage-timings (Issue 10-051), and --dry-run or
# --verbose prints the average of the last five runs per stage. Hardcoded
# estimates here had drifted by one to two orders of magnitude -- "~42 hours" for
# a stage measuring ~40 minutes, "~30 min" for one measuring ~17 seconds -- and
# stage 8 carried two contradictory numbers in this same file. A measured number
# cannot rot; an estimate in a comment always does.
#   6. Embeddings       - Generate poem embeddings via the inference server
#   7. Similarity       - Build similarity matrix
#   8. Diversity        - Pre-compute diversity cache
#   9. Generate HTML    - Generate poem pages, gallery, and source browser
#  10. Generate WordCloud - Generate the word-cloud menu and per-word pages
#
# Stages are selected individually with named flags (--extract,
# --generate-diversity, etc.) or by stage number (--stage 8,
# --stage=5). Use --full to run all 10 stages.
#
# Usage: ./run.sh [FLAGS] [PROJECT_DIR]
#
# ── The no-defaults contract (Issue 10-065) ─────────────────────────────────
# Every value this script hands to a stage must arrive on the command line.
# There are no invented numbers here, and nothing is read from config.lua to
# stand in for a flag the operator did not type. The reason is reproducibility:
# a guessed value is invisible in the output, so two runs typed identically
# could build different websites with nothing in the log to explain it.
#
# When values are absent the script does NOT stop at the first one. It works out
# every value the SELECTED stages will consume, collects all the absent ones, and
# prints them together -- so one run tells the operator the whole command they
# should have typed. See the "Required values" fold below.
#
# On/off flags (--force, --verbose, --quiet, --dry-run, --debug, --low-priority)
# are exempt, and the distinction is not arbitrary: for those, absence IS the
# value. Nothing is consulted to decide "off". Compare --boosts, whose absence
# used to mean "go ask config.privacy.include_boosts" -- that is a fallback, so
# it became a required yes/no.
#
# Two flags keep a DERIVED default, and the difference is worth naming: --dir and
# --output are computed once, from the project root, into a single variable that
# every path below is then built from. A default computed in one visible place is
# a different thing from a fallback consulted at ten scattered call sites.
#
# ── NEVER put a double quote inside an inline Lua block ────────────────────
# Several stages run Lua as an inline chunk, passed to luajit with its -e flag
# followed by a double-quoted string. (That pattern is spelled out indirectly
# here on purpose: the checker below greps for it, and a comment containing it
# verbatim would match itself.) The Lua source sits inside a shell
# DOUBLE-QUOTED string, so the first stray " ends the
# argument. Everything after it becomes separate shell words handed to luajit as
# script arguments -- and modules that infer their project root from arg[1]
# (src/semantic-color-calculator.lua does) then take one of those words as the
# root. The observed symptom was a stage dying on "Failed to load config from
# is/config.lua", where "is" was the third word of an ENGLISH COMMENT inside the
# chunk. bash -n cannot catch it: the script is still syntactically valid.
#
# Use single quotes, or no quotes, in anything inside those blocks -- including
# comments, which are the easy place to forget. To check every block at once,
# run scripts/check-inline-lua-quotes; every block must report exactly 2 quotes,
# the opening and the closing one and nothing else.

# {{{ setup_dir_path
# The project-root convention: a hard-coded path that any argument overrides, so
# the script runs correctly from any working directory. This is NOT one of the
# value fallbacks Issue 10-065 removed -- it is the location of the project
# itself, which must be known before the script can read anything at all
# (including the config that a fallback would have consulted).
setup_dir_path() {
    if [ -n "$1" ]; then
        echo "$1"
    else
        echo "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
    fi
}
# }}}

# {{{ Signal handling
# Trap Ctrl+C so the script actually exits when the operator interrupts.
# Bash on its own does not always propagate SIGINT to long-running children
# (luajit's tight inner loops in particular eat the signal), so we kill
# every background job in our process group and exit non-zero. Exit code
# 130 is the conventional value for "terminated by SIGINT" (128 + signal#).
cleanup_on_interrupt() {
    echo
    echo "Interrupted by user (SIGINT)" >&2
    # Kill anything we backgrounded; suppress errors when there are none.
    jobs -p | xargs -r kill 2>/dev/null
    # Best-effort kill the entire process group too, in case a child
    # spawned its own children without forwarding signals.
    kill -- -$$ 2>/dev/null
    exit 130
}
trap cleanup_on_interrupt INT TERM

# WE_STARTED_INFERENCE_SERVER tracks whether THIS run started the llama.cpp
# server itself (because validation failed at startup). If it's true, the
# EXIT trap below shuts the server down again. If the operator (or a prior
# run) was already running a server when we started, we leave it alone —
# never kill what we did not start.
WE_STARTED_INFERENCE_SERVER=false

# cleanup_inference_server: gracefully terminate the llama.cpp server we
# auto-started during the pre-flight validation phase. Runs on every exit
# path (normal completion, SIGINT/SIGTERM via cleanup_on_interrupt, errors
# that hit `exit`). The PID is read from a file the start script writes;
# if the file is missing or stale (PID no longer alive) we silently bow
# out — this is best-effort cleanup, not a contract.
cleanup_inference_server() {
    if ! $WE_STARTED_INFERENCE_SERVER; then
        return
    fi
    local pid_file="$DIR/tmp/shared-memory/llamacpp-server.pid"
    if [ ! -f "$pid_file" ]; then
        return
    fi
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        # Stale PID file — clean it up and move on.
        rm -f "$pid_file"
        return
    fi
    echo "Shutting down inference server (PID $pid) that this run started..." >&2
    kill "$pid" 2>/dev/null
    # Give the server up to 5 s to exit on SIGTERM. Most well-behaved
    # processes shut down within a second; the timeout is generous.
    local i=0
    while [ "$i" -lt 5 ]; do
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        sleep 1
        i=$((i + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
        echo "  server did not exit on SIGTERM; sending SIGKILL" >&2
        kill -9 "$pid" 2>/dev/null
    fi
    rm -f "$pid_file"
}

# {{{ Build-record rollback (Issue 10-065)
# The build record (output/generation-metadata.json) is written BEFORE the stages
# run, so that a build interrupted halfway still leaves its parameters behind.
# The cost of writing early is that a run which fails immediately replaces a
# record describing a real build with one describing nothing -- demonstrated
# during this issue's development, when a mistyped --model was caught by the
# stage-9 embeddings check AFTER the record had already been overwritten.
#
# The resolution keeps the early write and makes it reversible: the record about
# to be replaced is copied into the RAM tier first, and put back if the run does
# not reach the end. Both properties at once -- an interrupted build leaves its
# parameters, and a failed build leaves the previous record intact.
#
# These are empty until write_generation_metadata caches something, so the
# restore is a no-op on every run that writes no record (stages 1-4), on --help,
# and on a failure before the record is reached.
METADATA_TARGET=""
METADATA_BACKUP=""

restore_previous_generation_metadata() {
    local status="$1"
    # Reaching the end means the new record is the true one; keep it.
    [ "$status" -eq 0 ] && return
    # Nothing was cached: either no record was written this run, or none existed
    # to begin with. In both cases there is nothing to put back.
    [ -z "$METADATA_BACKUP" ] && return
    [ -f "$METADATA_BACKUP" ] || return
    if cp "$METADATA_BACKUP" "$METADATA_TARGET"; then
        echo "Build did not complete; restored the previous build record." >&2
        echo "  ($METADATA_TARGET)" >&2
    else
        echo "Warning: could not restore the previous build record from" >&2
        echo "  $METADATA_BACKUP -- it is still there, in RAM, until reboot." >&2
    fi
}
# }}}

# One EXIT trap, because bash has only one: setting a second would silently
# replace the first. Capturing $? must be the very first thing this does --
# any command run before it overwrites the status being reported on.
on_exit() {
    local status=$?
    restore_previous_generation_metadata "$status"
    cleanup_inference_server
}
trap on_exit EXIT
# }}}

# {{{ TUI Library
# The interactive menu library, which -I needs. Sourced here (before anything
# runs) because a shell function must be defined before it is called.
#
# Issue 10-065: the load is conditional but the CONSEQUENCE of a failed load is
# not. Previously a missing library set TUI_AVAILABLE=false and -I quietly ran a
# different, much older interactive mode instead -- the operator asked for one
# program and silently got another. Now the load stays conditional (a machine
# without the library must still be able to run every non-interactive stage) but
# interactive_mode_tui hard-errors if the library is not actually here. The check
# lives at the point of use, which is the only place that knows it was needed.
LIBS_DIR="/home/ritz/programming/ai-stuff/scripts/libs"
if [[ -f "${LIBS_DIR}/lua-menu.sh" ]] && command -v luajit &>/dev/null; then
    source "${LIBS_DIR}/lua-menu.sh"
fi
# }}}

# {{{ show_help
# {{{ show_help
# Reference, not rationale. Every flag gets one line saying what it does and
# which stages need it; WHY a flag works the way it does belongs in the comments
# at its implementation, not in front of someone who just wants the spelling.
show_help() {
    cat << 'EOF'
Usage: ./run.sh [FLAGS] [PROJECT_DIR]

Runs the poem processing pipeline. Pick stages by name or number; they always
run in pipeline order. Values are required per-stage -- run with just your
stage flags and it will list what else it needs.

Pipeline Stages:
  --update-words        Stage 1:  Sync input files from words repository
  --extract             Stage 2:  Extract content from backup archives
  --parse               Stage 3:  Parse poems into poems.json
  --validate            Stage 4:  Run poem validation
  --catalog-images      Stage 5:  Catalog images from input directories
  --generate-embeddings Stage 6:  Generate embeddings via the inference server
  --generate-similarity Stage 7:  Build similarity matrix
  --generate-diversity  Stage 8:  Pre-compute diversity cache
  --generate-html       Stage 9:  Generate poem pages, gallery, source browser
  --generate-wordcloud  Stage 10: Generate word-cloud menu and per-word pages

  --stage N             Select a stage by number (--stage 8, --stage=5)
  --full                Run all stages 1-10

Required values ([n] = the stages that need it):
  --threads N           Worker thread count                        [7,9]
  --pages N             Pages generated per poem                   [7,8,9]
  --poems-per-page N    Poems per similar/different page           [7,8,9]
  --chrono-per-page N   Poems per chronological page               [9,10]
  --wordcloud-words N   Words in the cloud, or "all"               [6,10]
  --wordcloud-poems N   Poems per word-cloud page                  [10]
  --model NAME          Embedding model                            [6,7,8,9,10]
  --server NAME         Inference server, by name from config.lua  [6]
  --boosts yes|no       Include fediverse boosts/reblogs           [2,3]

Optional:
  --seed N              Master randomization seed. Randomized and recorded
                        if omitted.
  --force               Force regeneration even if files are fresh
  --force-stage N       Force regenerate one stage only (1-10)
  --dir PATH            Assets directory      (default: <project>/assets)
  --output PATH         Site output directory (default: <project>/output)

Output Control:
  --quiet               Suppress progress messages
  --verbose             Show detailed progress
  --dry-run             Show what would run, without running it
  --debug               Write logs to output/debug-logs/ and keep them
  --low-priority        Run heavy stages at nice -n 10

Other:
  -I, --interactive     Launch the TUI (with command preview)
  --list-servers        List inference servers and exit
  --list-external       List configured external file sources
  --sync-only NAME      Sync one external source and exit
  -h, --help            Show this message

Examples:
  ./run.sh --generate-html            # lists the values it still needs
  ./run.sh --stage 4                  # validation needs no values
  ./run.sh --full --threads 8 --pages 3 --poems-per-page 33 \
      --chrono-per-page 7 --wordcloud-words all --wordcloud-poems 50 \
      --model nomic-embed-text-v1.5 --server local --boosts no

Notes:
  - Stage timings: run with --dry-run or --verbose; the plan shows each
    stage's measured average from .stage-timings.
  - Caches are written under assets/embeddings/<model>/.
  - The generated site is large; check `du -sh output/` before deploying.
EOF
}
# }}}
# }}}

# {{{ Parse command line arguments
DIR=""
ASSETS_DIR=""
OUTPUT_DIR=""
INTERACTIVE=false

# Stage flags (boolean)
UPDATE_WORDS=false
EXTRACT=false
PARSE=false
VALIDATE=false
CATALOG_IMAGES=false
GENERATE_EMBEDDINGS=false
GENERATE_SIMILARITY=false
GENERATE_DIVERSITY=false
GENERATE_HTML=false
GENERATE_WORDCLOUD=false

# Config flags. Every one of these starts EMPTY and stays empty unless the
# operator types it (Issue 10-065). Empty is not "use a default" -- empty is the
# state the requirement gate below reports as missing. Nothing in this script
# substitutes a value for an empty one.
THREADS=""
# Boost inclusion: the string "yes" or "no", from --boosts. There used to be two
# mechanisms for this -- an INCLUDE_BOOSTS boolean read by extraction and a
# BOOSTS_ARG string forwarded to parsing -- fed by three flag spellings, one of
# which appeared TWICE in the case statement below. Bash case takes the first
# match, so the second branch was unreachable and --include-boosts only ever
# reached the parse stage, never extraction. One flag, one variable, both stages.
BOOSTS=""
FORCE=false
# Issue 10-016: Per-stage force flags
FORCE_STAGE_1=false
FORCE_STAGE_2=false
FORCE_STAGE_3=false
FORCE_STAGE_4=false
FORCE_STAGE_5=false
FORCE_STAGE_6=false
FORCE_STAGE_7=false
FORCE_STAGE_8=false
FORCE_STAGE_9=false
FORCE_STAGE_10=false
QUIET=false
VERBOSE=false
DRY_RUN=false
# --debug: route all logs to output/ (durable disk) instead of the RAM-backed
# tmp/ symlink, and preserve them on exit. Added to diagnose a hard GPU lock:
# such a freeze forces a power-cycle, and the tmpfs-backed tmp/ is wiped on
# reboot, taking every diagnostic with it. See the setup block after `cd $DIR`.
DEBUG=false
# Issue 10-028: Lower process priority for UI responsiveness
LOW_PRIORITY=false
# The embedding model. Issue 10-065 made --model required, which collapsed what
# used to be two variables into one: there was a CLI_MODEL ("what the operator
# typed, if anything") and a MODEL_NAME ("what we resolved, possibly from
# config.lua"), and the gap between them was exactly where a --model could go
# missing. With the flag required they are the same value by construction, so
# only MODEL_NAME survives. It is still recorded on the per-run notepad
# (tmp/shared-memory/run-overrides.lua) because child programs resolve the model
# through that notepad rather than through argv.
MODEL_NAME=""
# Issue 8-022: Pagination settings for HTML generation
PAGES=""
POEMS_PER_PAGE=""
# Poems per chronological page. Declared here rather than springing into
# existence inside the case statement, so the requirement gate can see it.
CHRONO_PER_PAGE=""

# Issue 10-058: master seed for all randomization (word-cloud shuffle, image
# order). Issue 10-065 removed the two lower tiers of its old resolution chain.
# It used to be: --seed, else config.randomization.seed, else a number mixed from
# the clock and the process id. That third tier is the reason the change was
# worth making -- it MANUFACTURED a value that had never existed before, so the
# operator who typed the command did not choose the seed and could not have
# predicted it. The build was recorded afterward, which makes it reproducible in
# hindsight but not intentional. Now --seed is required and there is one tier.
RANDOM_SEED=""

# Issue 8-043: Word cloud configuration
# Word-cloud word count: a number, or the literal "all" for every word. Both the
# CLI (--wordcloud-words all) and the menu's "All Words" checkbox set this single
# value -- there is no separate "all" flag to keep in sync.
WORDCLOUD_WORDS=""
# Issue 8-050d: Poems per word-cloud page
WORDCLOUD_POEMS=""

# Issue 10-003b: External file management
LIST_EXTERNAL=false
SYNC_ONLY=""

# Issue 10-017: Inference server configuration
INFERENCE_SERVER=""
LIST_SERVERS=false

# Track if any stage flag was explicitly set
STAGE_FLAG_SET=false

# {{{ take_flag_value()
# Validate the value half of a "--flag value" pair and leave it in FLAG_VALUE.
#
# Issue 10-065: two shapes of mistake used to pass silently, and the second is
# the dangerous one.
#   ./run.sh --threads              -- value is "" (end of the command line).
#                                      Harmless-looking: it reads as "absent",
#                                      and the requirement gate catches it.
#   ./run.sh --threads --pages 5    -- value is "--pages". This one LOOKS
#                                      supplied. The gate would accept it, the
#                                      thread count would be the string
#                                      "--pages", --pages itself would then be
#                                      absent, and the failure would surface much
#                                      later inside a child program with an error
#                                      that names neither flag.
#
# Why this writes to a global instead of printing its answer: a command
# substitution -- THREADS=$(flag_value ...) -- runs the function in a SUBSHELL,
# where `exit 1` kills only that subshell. The script would carry on with an
# empty value and no error. Writing to FLAG_VALUE keeps the function in this
# shell, so its exit is the script's exit.
FLAG_VALUE=""
take_flag_value() {
    local flag="$1"
    local value="$2"
    if [ -z "$value" ]; then
        echo "Error: $flag needs a value and none followed it." >&2
        echo "       Write it as: $flag <value>" >&2
        exit 1
    fi
    if [ "${value:0:2}" = "--" ]; then
        echo "Error: $flag needs a value, but the next thing on the command" >&2
        echo "       line was '$value', which is another flag." >&2
        echo "       Write it as: $flag <value> $value ..." >&2
        exit 1
    fi
    FLAG_VALUE="$value"
}
# }}}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -I|--interactive)
            INTERACTIVE=true
            shift
            ;;
        --dir)
            take_flag_value "--dir" "$2"; ASSETS_DIR="$FLAG_VALUE"
            shift 2
            ;;
        --dir=*)
            take_flag_value "--dir" "${1#*=}"; ASSETS_DIR="$FLAG_VALUE"
            shift
            ;;
        --output)
            take_flag_value "--output" "$2"; OUTPUT_DIR="$FLAG_VALUE"
            shift 2
            ;;
        --output=*)
            take_flag_value "--output" "${1#*=}"; OUTPUT_DIR="$FLAG_VALUE"
            shift
            ;;
        --threads)
            take_flag_value "--threads" "$2"; THREADS="$FLAG_VALUE"
            shift 2
            ;;
        --threads=*)
            take_flag_value "--threads" "${1#*=}"; THREADS="$FLAG_VALUE"
            shift
            ;;
        # Issue 10-058/10-065: the master seed for every randomization site in
        # this build. The only source now -- config.randomization.seed is no
        # longer consulted and no seed is ever manufactured.
        --seed)
            take_flag_value "--seed" "$2"; RANDOM_SEED="$FLAG_VALUE"
            shift 2
            ;;
        --seed=*)
            take_flag_value "--seed" "${1#*=}"; RANDOM_SEED="$FLAG_VALUE"
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        # Issue 10-016: Per-stage force regeneration (space-separated format)
        --force-stage)
            stage_num="$2"
            case "$stage_num" in
                1) FORCE_STAGE_1=true ;;
                2) FORCE_STAGE_2=true ;;
                3) FORCE_STAGE_3=true ;;
                4) FORCE_STAGE_4=true ;;
                5) FORCE_STAGE_5=true ;;
                6) FORCE_STAGE_6=true ;;
                7) FORCE_STAGE_7=true ;;
                8) FORCE_STAGE_8=true ;;
                9) FORCE_STAGE_9=true ;;
                10) FORCE_STAGE_10=true ;;
                *)
                    echo "ERROR: Invalid stage number: $stage_num (valid: 1-10)" >&2
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        # Issue 10-016: Per-stage force regeneration (= format for backward compatibility)
        --force-stage=*)
            stage_num="${1#*=}"
            case "$stage_num" in
                1) FORCE_STAGE_1=true ;;
                2) FORCE_STAGE_2=true ;;
                3) FORCE_STAGE_3=true ;;
                4) FORCE_STAGE_4=true ;;
                5) FORCE_STAGE_5=true ;;
                6) FORCE_STAGE_6=true ;;
                7) FORCE_STAGE_7=true ;;
                8) FORCE_STAGE_8=true ;;
                9) FORCE_STAGE_9=true ;;
                10) FORCE_STAGE_10=true ;;
                *)
                    echo "ERROR: Invalid stage number: $stage_num (valid: 1-10)" >&2
                    exit 1
                    ;;
            esac
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        # Boost inclusion (reshared posts), read by both the extraction and the
        # parse stages -- they change what poems.json contains, so they only take
        # effect on a (re)parse.
        #
        # Issue 10-065 replaced three flag spellings (--include-boosts,
        # --no-boosts, --exclude-boosts) with one that carries its answer, for
        # two reasons. First, absence used to mean "read
        # config.privacy.include_boosts", which is a fallback. Second, the old
        # --include-boosts was written into this case statement TWICE; bash takes
        # the first match, so the second branch never ran and the flag reached
        # only half the pipeline. A single branch cannot be shadowed by itself.
        --boosts)
            take_flag_value "--boosts" "$2"; BOOSTS="$FLAG_VALUE"
            shift 2
            ;;
        --boosts=*)
            take_flag_value "--boosts" "${1#*=}"; BOOSTS="$FLAG_VALUE"
            shift
            ;;
        # --debug: persist logs to output/ (survives the reboot a hard GPU
        # lock forces). Handled after DIR is resolved, below.
        --debug)
            DEBUG=true
            shift
            ;;
        # Issue 10-028: Lower process priority for UI responsiveness
        --low-priority)
            LOW_PRIORITY=true
            shift
            ;;
        --model)
            take_flag_value "--model" "$2"; MODEL_NAME="$FLAG_VALUE"
            shift 2
            ;;
        --model=*)
            take_flag_value "--model" "${1#*=}"; MODEL_NAME="$FLAG_VALUE"
            shift
            ;;
        # Issue 8-022: Pagination flags for HTML generation
        --pages)
            take_flag_value "--pages" "$2"; PAGES="$FLAG_VALUE"
            shift 2
            ;;
        --pages=*)
            take_flag_value "--pages" "${1#*=}"; PAGES="$FLAG_VALUE"
            shift
            ;;
        --poems-per-page)
            take_flag_value "--poems-per-page" "$2"; POEMS_PER_PAGE="$FLAG_VALUE"
            shift 2
            ;;
        --poems-per-page=*)
            take_flag_value "--poems-per-page" "${1#*=}"; POEMS_PER_PAGE="$FLAG_VALUE"
            shift
            ;;
        --chrono-per-page)
            take_flag_value "--chrono-per-page" "$2"; CHRONO_PER_PAGE="$FLAG_VALUE"
            shift 2
            ;;
        --chrono-per-page=*)
            take_flag_value "--chrono-per-page" "${1#*=}"; CHRONO_PER_PAGE="$FLAG_VALUE"
            shift
            ;;
        # Issue 8-043: Word cloud configuration. Word count is set with
        # --wordcloud-words N, or "--wordcloud-words all" for every word.
        --wordcloud-words)
            take_flag_value "--wordcloud-words" "$2"; WORDCLOUD_WORDS="$FLAG_VALUE"
            shift 2
            ;;
        --wordcloud-words=*)
            take_flag_value "--wordcloud-words" "${1#*=}"; WORDCLOUD_WORDS="$FLAG_VALUE"
            shift
            ;;
        # Issue 8-050d: Poems per word-cloud page
        --wordcloud-poems)
            take_flag_value "--wordcloud-poems" "$2"; WORDCLOUD_POEMS="$FLAG_VALUE"
            shift 2
            ;;
        --wordcloud-poems=*)
            take_flag_value "--wordcloud-poems" "${1#*=}"; WORDCLOUD_POEMS="$FLAG_VALUE"
            shift
            ;;
        # Issue 8-011/10-065: the second --include-boosts branch was here. It was
        # unreachable (the first one, above, matched every time) and it fed a
        # separate INCLUDE_BOOSTS variable that only the extraction stage read --
        # which is why passing the flag changed parsing but not extraction. Both
        # branches and both variables are gone; --boosts yes|no replaces them.
        # Issue 10-003b: External file management
        --list-external)
            LIST_EXTERNAL=true
            shift
            ;;
        --sync-only)
            take_flag_value "--sync-only" "$2"; SYNC_ONLY="$FLAG_VALUE"
            shift 2
            ;;
        --sync-only=*)
            take_flag_value "--sync-only" "${1#*=}"; SYNC_ONLY="$FLAG_VALUE"
            shift
            ;;
        # Issue 10-017: Inference server configuration
        --server)
            take_flag_value "--server" "$2"; INFERENCE_SERVER="$FLAG_VALUE"
            shift 2
            ;;
        --server=*)
            take_flag_value "--server" "${1#*=}"; INFERENCE_SERVER="$FLAG_VALUE"
            shift
            ;;
        --list-servers)
            LIST_SERVERS=true
            shift
            ;;
        # Stage flags
        --update-words)
            UPDATE_WORDS=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --extract)
            EXTRACT=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --parse)
            PARSE=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --validate)
            VALIDATE=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --catalog-images)
            CATALOG_IMAGES=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --generate-embeddings)
            GENERATE_EMBEDDINGS=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --generate-similarity)
            GENERATE_SIMILARITY=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --generate-diversity)
            GENERATE_DIVERSITY=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --generate-html)
            GENERATE_HTML=true
            STAGE_FLAG_SET=true
            shift
            ;;
        --generate-wordcloud)
            GENERATE_WORDCLOUD=true
            STAGE_FLAG_SET=true
            shift
            ;;
        # --stage N or --stage=N — select a specific stage by number.
        # Stage map (numeric): 1=update-words, 2=extract, 3=parse,
        # 4=validate, 5=catalog-images, 6=generate-embeddings,
        # 7=generate-similarity, 8=generate-diversity, 9=generate-html,
        # 10=generate-wordcloud. Can be repeated (e.g. --stage 6 --stage 7).
        --stage)
            case "$2" in
                1) UPDATE_WORDS=true ;;
                2) EXTRACT=true ;;
                3) PARSE=true ;;
                4) VALIDATE=true ;;
                5) CATALOG_IMAGES=true ;;
                6) GENERATE_EMBEDDINGS=true ;;
                7) GENERATE_SIMILARITY=true ;;
                8) GENERATE_DIVERSITY=true ;;
                9) GENERATE_HTML=true ;;
                10) GENERATE_WORDCLOUD=true ;;
                *) echo "Error: --stage expects a number 1-10, got: $2" >&2; exit 1 ;;
            esac
            STAGE_FLAG_SET=true
            shift 2
            ;;
        --stage=*)
            STAGE_NUM="${1#*=}"
            case "$STAGE_NUM" in
                1) UPDATE_WORDS=true ;;
                2) EXTRACT=true ;;
                3) PARSE=true ;;
                4) VALIDATE=true ;;
                5) CATALOG_IMAGES=true ;;
                6) GENERATE_EMBEDDINGS=true ;;
                7) GENERATE_SIMILARITY=true ;;
                8) GENERATE_DIVERSITY=true ;;
                9) GENERATE_HTML=true ;;
                10) GENERATE_WORDCLOUD=true ;;
                *) echo "Error: --stage expects a number 1-10, got: $STAGE_NUM" >&2; exit 1 ;;
            esac
            STAGE_FLAG_SET=true
            shift
            ;;
        --full)
            # ALL stages including expensive embedding generation (1-10)
            UPDATE_WORDS=true
            EXTRACT=true
            PARSE=true
            VALIDATE=true
            CATALOG_IMAGES=true
            GENERATE_EMBEDDINGS=true
            GENERATE_SIMILARITY=true
            GENERATE_DIVERSITY=true
            GENERATE_HTML=true
            GENERATE_WORDCLOUD=true
            STAGE_FLAG_SET=true
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
        *)
            DIR="$1"
            shift
            ;;
    esac
done

# No implicit stages — require explicit selection. The operator should
# say what they want to run: a named stage flag, --stage N, or --full.
if ! $STAGE_FLAG_SET && ! $INTERACTIVE && ! $LIST_SERVERS; then
    echo "Error: no stages selected. Use --full, a named stage flag" >&2
    echo "  (e.g. --generate-diversity), --stage N, or -I for interactive mode." >&2
    echo "  Run with --help for the full flag list." >&2
    exit 1
fi
# }}}

# {{{ Required values (Issue 10-065)
# The gate that replaced every default and config fallback in this script.
#
# Two properties this is built around, both deliberate:
#
#   Requirements follow the SELECTED stages. --validate alone requires nothing;
#   --stage 10 requires the word-cloud values and the seed but not the thread
#   count. A gate that demanded every value on every run would be demanding
#   values the run will never read, which teaches the operator to type noise --
#   and noise types just as easily when it is wrong.
#
#   Absent values are COLLECTED, never fatal on sight. Exiting at the first
#   absence makes the operator play twenty questions: four missing values cost
#   four runs to discover. Every check below records and continues; one report
#   at the end lists the whole set.
#
# The table is the honest documentation of what each stage actually reads, which
# is why it is a table and not a chain of ifs -- a new stage declares its needs
# on one line, in one place, next to every other stage's.
#
# Row format:  VARIABLE ; flag usage ; why it is needed ; consumers ; record key
# where "consumers" is a comma-separated list of STAGE_BOOLEAN:stage-number, and
# "record key" is the name this value is written under in the build's
# generation-metadata.json.
#
# The record key lives HERE, in the same row as everything else, so the gate and
# the build record cannot drift apart. Adding a flag means adding one row, and it
# is then simultaneously required, explained in the missing-values report, and
# recorded in the artifact -- rather than three edits in three places, of which
# somebody eventually does two.
#
# The field separator is ";" rather than the more obvious "|" because one flag's
# usage text has to READ the way the operator must type it -- "--boosts yes|no"
# contains a literal pipe. Choosing a separator that cannot appear in the data
# keeps the split a plain one-line read instead of positional index arithmetic.
REQUIRED_VALUES=(
    "THREADS;--threads N;parallel worker count;GENERATE_SIMILARITY:7,GENERATE_HTML:9;threads"
    "PAGES;--pages N;pages generated per poem;GENERATE_SIMILARITY:7,GENERATE_DIVERSITY:8,GENERATE_HTML:9;pages"
    "POEMS_PER_PAGE;--poems-per-page N;poems per similar/different page;GENERATE_SIMILARITY:7,GENERATE_DIVERSITY:8,GENERATE_HTML:9;poems_per_page"
    "CHRONO_PER_PAGE;--chrono-per-page N;poems per chronological page;GENERATE_HTML:9,GENERATE_WORDCLOUD:10;chrono_per_page"
    "WORDCLOUD_WORDS;--wordcloud-words N;words in the cloud, or the word 'all';GENERATE_EMBEDDINGS:6,GENERATE_WORDCLOUD:10;wordcloud_words"
    "WORDCLOUD_POEMS;--wordcloud-poems N;poems per word-cloud page;GENERATE_WORDCLOUD:10;wordcloud_poems"
    # --seed is NOT in this table: an absent seed is randomized, not refused.
    # It is still RECORDED (see resolve_random_seed), which is what makes an
    # unseeded build reproducible after the fact -- the property Issue 10-058
    # built the seed for. A required seed would mean no build can start without
    # inventing a number to type, and a number typed to satisfy a prompt is not
    # a more deliberate choice than one the machine picked and wrote down.
    "MODEL_NAME;--model NAME;embedding model, and the cache directory it names;GENERATE_EMBEDDINGS:6,GENERATE_SIMILARITY:7,GENERATE_DIVERSITY:8,GENERATE_HTML:9,GENERATE_WORDCLOUD:10;model"
    "INFERENCE_SERVER;--server NAME;inference server, by name from config.lua;GENERATE_EMBEDDINGS:6;server"
    "BOOSTS;--boosts yes|no;whether reshared posts are included;EXTRACT:2,PARSE:3;boosts"
)

# Each entry: "flag usage;reason;stage numbers that wanted it"
MISSING_VALUES=()

# {{{ collect_missing_values()
# Walk the table, and for each value work out whether any SELECTED stage
# consumes it. If one does and the value is empty, record it. Never exits --
# recording and continuing is the whole point.
collect_missing_values() {
    local row var usage reason consumers record_key
    local entries entry stage_var stage_num wanted_by
    for row in "${REQUIRED_VALUES[@]}"; do
        IFS=';' read -r var usage reason consumers record_key <<< "$row"

        # Which of this value's consumer stages did the operator actually select?
        wanted_by=""
        IFS=',' read -r -a entries <<< "$consumers"
        for entry in "${entries[@]}"; do
            stage_var="${entry%%:*}"
            stage_num="${entry##*:}"
            # Indirect expansion: ${!stage_var} reads the variable NAMED by
            # stage_var, so the table can refer to stage booleans by name.
            if [ "${!stage_var}" = "true" ]; then
                wanted_by="${wanted_by:+$wanted_by, }$stage_num"
            fi
        done

        # No selected stage reads this value -> not required on this run.
        [ -z "$wanted_by" ] && continue
        # Supplied. (Any non-empty string counts here; whether it is a sensible
        # number is the child program's business, not this gate's.)
        [ -n "${!var}" ] && continue

        MISSING_VALUES+=("$usage;$reason;$wanted_by")
    done
}
# }}}

# {{{ report_missing_values()
# Print every absent value at once and stop. The flag spelling starts each line
# so the whole block can be read straight into a command line; the explanation
# rides behind a "#" so a copied line is still valid shell.
report_missing_values() {
    if [ "${#MISSING_VALUES[@]}" -eq 0 ]; then
        return 0
    fi

    # Width pass, so the "#" comments line up and the eye can scan the flags.
    local row usage reason stages width=0
    for row in "${MISSING_VALUES[@]}"; do
        IFS=';' read -r usage reason stages <<< "$row"
        [ "${#usage}" -gt "$width" ] && width=${#usage}
    done

    echo "" >&2
    echo "can't run generation script, missing these flags:" >&2
    echo "" >&2
    for row in "${MISSING_VALUES[@]}"; do
        IFS=';' read -r usage reason stages <<< "$row"
        # "stage 9" reads wrong for a list; "stages 7, 8, 9" reads wrong for one.
        local noun="stage"
        case "$stages" in *,*) noun="stages" ;; esac
        printf '  %-*s  # %s (%s %s)\n' "$width" "$usage" "$reason" "$noun" "$stages" >&2
    done
    echo "" >&2
    echo "Every value the pipeline consumes must be given explicitly." >&2
    echo "run.sh has no defaults and reads no fallbacks from config.lua." >&2
    echo "Only the stages you selected are asked about; --help explains which." >&2
    exit 1
}
# }}}

# {{{ validate_supplied_values()
# Shape checks for values that DID arrive. Separate from the gate above on
# purpose: "absent" is a list the operator can act on all at once, but "present
# and malformed" is a typo in a specific place, and pointing at it immediately
# is more useful than burying it in a list of unrelated absences.
validate_supplied_values() {
    # The seed must round-trip through a command line, a JSON file and Lua's
    # randomseed unchanged, so it is a non-negative integer or it is nothing.
    # Substituting a working seed for a broken one would defeat the entire
    # reason the seed exists.
    if [ -n "$RANDOM_SEED" ]; then
        case "$RANDOM_SEED" in
            *[!0-9]*)
                echo "ERROR: --seed '$RANDOM_SEED' is not a non-negative integer." >&2
                exit 1
                ;;
        esac
    fi

    # --boosts carries its own answer, so the answer has to be one we know.
    if [ -n "$BOOSTS" ] && [ "$BOOSTS" != "yes" ] && [ "$BOOSTS" != "no" ]; then
        echo "ERROR: --boosts takes 'yes' or 'no', not '$BOOSTS'." >&2
        echo "       It decides whether reshared (boosted) posts become poems." >&2
        exit 1
    fi
}
# }}}
# }}}

# {{{ Derived on/off settings
# These translate presence-flags into the shapes other programs want. They are
# not defaults: an absent --force means off because that is what the flag means,
# not because anything was consulted to decide it.

# Issue 8-032: Convert FORCE to Lua boolean for passing to Lua functions
if $FORCE; then
    FORCE_LUA="true"
else
    FORCE_LUA="false"
fi

# Issue 10-028: Set up nice prefix for low priority execution
# When enabled, heavy operations run at nice level 10 (lower priority)
# This keeps the desktop/terminal responsive during long pipeline runs
NICE_PREFIX=""
if $LOW_PRIORITY; then
    NICE_PREFIX="nice -n 10"
fi
# }}}

# {{{ Setup directories
DIR=$(setup_dir_path "$DIR")

# Issue 10-051: stage wall-clock timing. Sourced after DIR is final so the
# library knows where .stage-timings lives. Provides timed_stage (wrap a stage
# to record its duration on success) and stage_timing_label (render the measured
# estimate for the pre-flight list).
#
# Issue 10-065: a missing library is now fatal. It used to be replaced by a stub
# -- `timed_stage() { shift; "$@"; }` -- which ran the stage and recorded
# nothing. That is the quietest possible failure: the pipeline works, every stage
# runs, and the only symptom is that the pre-flight time estimates never improve,
# months later, for reasons nobody can reconstruct.
if [ ! -f "${DIR}/scripts/stage-timing.sh" ]; then
    echo "Error: stage-timing library not found: ${DIR}/scripts/stage-timing.sh" >&2
    echo "       It records each stage's wall-clock time to .stage-timings, which" >&2
    echo "       the pre-flight plan reads back as its duration estimates." >&2
    exit 1
fi
source "${DIR}/scripts/stage-timing.sh"
if ! command -v timed_stage >/dev/null; then
    echo "Error: ${DIR}/scripts/stage-timing.sh loaded but does not define timed_stage." >&2
    exit 1
fi

# {{{ Assets and output directories
# Issue 10-065: these are the two DERIVED values in the script, and the
# difference from a fallback is that the derivation happens exactly once, here,
# and every path below is built from the result.
#
# What it replaced: --dir used to be forwarded to main.lua as "--dir PATH" and
# nowhere else, while this script separately hardcoded "$DIR/assets/poems.json"
# for its own freshness checks -- so passing --dir pointed the child at one
# corpus and left the parent checking another. --output was worse: it reached
# exactly one line (the metadata write) while every stage wrote to "$DIR/output".
# A flag that is honoured in one place out of ten is not a flag, it is a trap.
if [ -z "$ASSETS_DIR" ]; then
    ASSETS_DIR="$DIR/assets"
fi
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$DIR/output"
fi

# The child programs take the assets root as "--dir PATH". Passed unconditionally
# now, because ASSETS_DIR is always resolved -- there is no "omit the flag and
# let the child decide" case left.
ASSETS_ARG="--dir $ASSETS_DIR"
# }}}

# Ensure we're in the right directory
cd "$DIR" || {
    echo "Error: Could not access directory $DIR" >&2
    exit 1
}
# }}}

# {{{ --debug: persistent logging
# Why this exists: a hard GPU lock forces a power-cycle, and the tmp/ symlink
# points at a tmpfs subdir under /tmp/ (RAM) that the reboot wipes — so the
# logs that would explain the freeze are gone before they can be read.
# --debug routes logs to output/debug-logs/ (durable disk) instead.
#
# Two mechanisms, working together:
#   1. NEOCITIES_LOG_DIR is exported so the child scripts that own the
#      inference logs — scripts/start-llamacpp-server.sh (llamacpp-server.log)
#      and generate-embeddings.sh (embedding_generation.log) — write there
#      and skip their usual end-of-run log deletion.
#   2. This script's own console output is tee'd to run.log, so whatever stage
#      was mid-flight at the instant of the freeze (including the GPU Vulkan
#      similarity/diversity stages, which log only to stdout) leaves a trail.
#
# Caveat worth knowing: on a true hard lock you must hard-power-cycle, and the
# kernel may not have flushed the last few seconds of file writes (dirty pages)
# to disk. Durable disk still captures vastly more than tmpfs, but the final
# line or two before the lock can still be lost.
if $DEBUG; then
    LOG_DIR="$OUTPUT_DIR/debug-logs"
    mkdir -p "$LOG_DIR"
    export NEOCITIES_LOG_DIR="$LOG_DIR"
    # The Vulkan C library reads VKC_DEBUG to switch its progress bars from the
    # animated single-line "\r" form to verbose, newline-terminated lines --
    # the right shape when stdout is the fsync-logger pipe below and we want a
    # durable, per-line history of a possibly-freezing run.
    export VKC_DEBUG=1
    # Don't reroute stdout through a pipe in interactive mode: the TUI checks
    # isatty() and a pipe would break its rendering. The child-script file
    # logs still land in LOG_DIR via the exported env var above.
    #
    # fsync-logger (not tee) is used so every line is fsync()'d to disk the
    # instant it is printed — the stage banners are exactly what triage needs,
    # and a hard lock right after a banner must not lose it to a dirty-page
    # buffer. Slow, but --debug is for catching a freeze, not for speed.
    if ! $INTERACTIVE; then
        exec > >("$DIR/scripts/fsync-logger" "$LOG_DIR/run.log") 2>&1
    fi
    echo "[DEBUG] Logging to $LOG_DIR (per-line fsync to disk; persists across reboots; logs kept on exit)"
fi
# }}}

# {{{ Issue 10-003b: Handle external file commands (immediate actions)
if $LIST_EXTERNAL; then
    "$DIR/scripts/sync-external-files" --list
    exit 0
fi

if [ -n "$SYNC_ONLY" ]; then
    "$DIR/scripts/sync-external-files" "$SYNC_ONLY"
    exit $?
fi
# }}}

# {{{ Issue 10-017: Handle Inference server commands (immediate actions)
if $LIST_SERVERS; then
    luajit -e "
        package.path = '$DIR/libs/?.lua;' .. package.path
        local inference = require('inference-server-config')
        inference.list_servers()
    "
    exit 0
fi
# }}}

# {{{ Materialize the RAM-backed tmp/ directory
# A bare `mkdir -p tmp` does NOT work here: tmp/ is a symlink, and if its target
# is missing (wiped on reboot) mkdir sees the link, reports "exists", and creates
# nothing. ensure-tmp-symlink is the project's idempotent, fail-loud helper for
# exactly this -- it creates the /tmp target the symlink points at. Done early
# because the per-run notepad and every stage log live underneath it.
"$DIR/scripts/ensure-tmp-symlink" "$DIR" || {
    echo "Error: could not materialize the tmp/ RAM directory (scripts/ensure-tmp-symlink)" >&2
    exit 1
}
# }}}

# NOTE (Issue 10-065): the embedding-model resolution and the per-run overrides
# notepad used to sit here. They moved BELOW the interactive menu and the
# requirement gate, and the ordering is the point: the old code resolved the
# model by asking config.lua whenever --model was absent, which is precisely the
# fallback this issue removed. Resolution cannot come before the check that the
# operator supplied the value -- and the check cannot come before the menu, which
# is the other way values arrive. See "Record this run's choices" further down.

# {{{ Logging functions
log_info() {
    if ! $QUIET; then
        echo "$1"
    fi
}

log_verbose() {
    if $VERBOSE; then
        echo "$1"
    fi
}

log_stage() {
    if ! $QUIET; then
        echo ""
        echo -e "${COLOR_MAGENTA}═══════════════════════════════════════════════════════════════════${COLOR_RESET}"
        echo -e "  ${COLOR_GREEN}$1${COLOR_RESET}"
        echo -e "${COLOR_MAGENTA}═══════════════════════════════════════════════════════════════════${COLOR_RESET}"
    fi
}

log_dry_run() {
    echo "[DRY-RUN] Would execute: $1"
}

# ANSI color codes for terminal output
# These add visual distinction to success/info/error messages
COLOR_GREEN="\033[92m"    # Bright green for success (✓, ✅)
COLOR_BLUE="\033[94m"     # Bright blue for info (ℹ️)
COLOR_RED="\033[91m"      # Bright red for errors (✗, ❌)
COLOR_YELLOW="\033[93m"   # Bright yellow for warnings (⚠️)
COLOR_MAGENTA="\033[95m"  # Bright magenta for stage delimiters
COLOR_RESET="\033[0m"     # Reset to default

# Colored symbol helpers
symbol_success() {
    echo -e "${COLOR_GREEN}$1${COLOR_RESET}"
}

symbol_info() {
    echo -e "${COLOR_BLUE}$1${COLOR_RESET}"
}

symbol_error() {
    echo -e "${COLOR_RED}$1${COLOR_RESET}"
}

symbol_warning() {
    echo -e "${COLOR_YELLOW}$1${COLOR_RESET}"
}
# }}}

# {{{ Issue 10-058: record the build's master seed
# A single integer governs every randomization site this run (the word-cloud
# shuffle and image-order randomization).
#
# Issue 10-065 deleted the resolver that used to live here. It tried --seed
# first, then config.randomization.seed, then MANUFACTURED one by mixing the
# clock with the process id. That last tier is why this mattered more than the
# other fallbacks: it invented a value that had never existed, so a build's most
# consequential input was chosen by nobody. It was recorded afterward, which
# makes such a build reproducible in hindsight but not intentional -- and the
# only way to learn what governed your word cloud was to read the metadata file
# after the fact. Now --seed is required by the stages that randomize, and the
# recording below documents a decision instead of disclosing an accident.

# {{{ write_generation_metadata()
# The record of what produced this build. A small JSON at the output root;
# written early (so an interrupted build still leaves it) and at the root (so
# per-stage clears, which only touch output/ subdirs, never wipe it).
#
# Issue 10-065: it used to record the seed, pages and poems-per-page only. That
# gap had a cost that was paid in full: after the word-cloud pages were lost,
# nothing in the build's own artifacts said what --wordcloud-words,
# --wordcloud-poems or --chrono-per-page had produced them, so 11 GB -- two
# thirds of the site -- could not be reproduced from its own record.
#
# It now writes every value the requirement gate asked for on this run, driven by
# the SAME table. That is the property worth keeping: the record cannot fall
# behind the flags, because adding a flag to REQUIRED_VALUES adds it here too.
#
# Only values this run actually needed are written. A run of stages 9 and 10 has
# no --server, and recording an empty one would claim something untrue about how
# the build was made.
write_generation_metadata() {
    mkdir -p "$OUTPUT_DIR"

    # Cache the record we are about to replace, in the RAM tier, so the EXIT trap
    # can put it back if this run does not finish. RAM is the right home: the
    # copy is meaningful only for the duration of this run, and a reboot that
    # wipes it also ends the run it belonged to.
    METADATA_TARGET="$OUTPUT_DIR/generation-metadata.json"
    if [ -f "$METADATA_TARGET" ]; then
        METADATA_BACKUP="$DIR/tmp/shared-memory/generation-metadata.previous.json"
        cp "$METADATA_TARGET" "$METADATA_BACKUP" || {
            # Refuse rather than overwrite irreversibly. The existing record is
            # the only description of what is currently in output/; replacing it
            # with no way back is worse than not recording this run at all.
            echo "Error: could not cache the existing build record to" >&2
            echo "  $METADATA_BACKUP" >&2
            echo "  Refusing to overwrite $METADATA_TARGET without a way back." >&2
            exit 1
        }
    fi

    local generated_at
    generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Which stages ran, by number, in pipeline order.
    local stages=()
    $UPDATE_WORDS        && stages+=(1)
    $EXTRACT             && stages+=(2)
    $PARSE               && stages+=(3)
    $VALIDATE            && stages+=(4)
    $CATALOG_IMAGES      && stages+=(5)
    $GENERATE_EMBEDDINGS && stages+=(6)
    $GENERATE_SIMILARITY && stages+=(7)
    $GENERATE_DIVERSITY  && stages+=(8)
    $GENERATE_HTML       && stages+=(9)
    $GENERATE_WORDCLOUD  && stages+=(10)
    local stages_json
    stages_json=$(IFS=,; echo "${stages[*]}")

    # Every required value that applied, as "key": "value" lines. Values are
    # emitted as JSON strings even when numeric: "all" is a legitimate
    # --wordcloud-words, so the column is not uniformly a number, and a reader
    # that must handle both is better served by one consistent type.
    local row var usage reason consumers record_key
    local entries entry stage_var wanted value_lines=()
    for row in "${REQUIRED_VALUES[@]}"; do
        IFS=';' read -r var usage reason consumers record_key <<< "$row"
        wanted=false
        IFS=',' read -r -a entries <<< "$consumers"
        for entry in "${entries[@]}"; do
            stage_var="${entry%%:*}"
            [ "${!stage_var}" = "true" ] && wanted=true
        done
        $wanted || continue
        [ -z "${!var}" ] && continue
        value_lines+=("    \"$record_key\": \"${!var}\"")
    done

    # Join with ",\n". NOT "${value_lines[*]}" with IFS=$',\n' -- bash uses only
    # the FIRST character of IFS as the separator for [*], so that produced one
    # long comma-joined line. Valid JSON, but this file is read by people.
    local values_json="" line
    local remaining=${#value_lines[@]}
    for line in "${value_lines[@]}"; do
        remaining=$((remaining - 1))
        if [ "$remaining" -gt 0 ]; then
            values_json+="$line,"$'\n'
        else
            values_json+="$line"
        fi
    done

    # The seed is written OUTSIDE the values block and unconditionally, because
    # it is no longer one of the required values (an absent --seed is randomized,
    # not refused) -- but recording it is the entire reason it exists. Its source
    # rides alongside so a reader can tell a chosen seed from a rolled one, which
    # is the distinction the record is for.
    cat > "$OUTPUT_DIR/generation-metadata.json" <<EOF
{
  "generated_at": "$generated_at",
  "stages": [$stages_json],
  "seed": $RANDOM_SEED,
  "seed_source": "$RANDOM_SEED_SOURCE",
  "values": {
$values_json
  }
}
EOF
}
# }}}
# }}}

# {{{ Stage execution functions

# {{{ run_update_words
run_update_words() {
    log_stage "📁 Stage 1/10: Updating input files from words repository"

    # Issue 10-016: Check both global and per-stage force flags (Stage 1)
    local stage_force=$FORCE
    $FORCE_STAGE_1 && stage_force=true

    # Issue 7-003: Pass force flag to skip file preservation
    local force_flag=""
    if $stage_force; then
        force_flag="--force"
    fi

    if $DRY_RUN; then
        log_dry_run "$DIR/scripts/update-words $force_flag"
        return 0
    fi

    # Issue 10-065: this was a warning that continued. It should not be. This
    # stage's whole job is to make input/ match the words repository, so a
    # failure means every stage after it reads a corpus that is not the one the
    # operator asked to publish -- and reads it without complaint, because the
    # files are all there, just old. A stale corpus is invisible in the output.
    "$DIR/scripts/update-words" $force_flag || {
        echo "Error: failed to sync input files from the words repository" >&2
        echo "       Every later stage would read a stale corpus, and would not" >&2
        echo "       be able to tell that it had. Fix the sync and re-run." >&2
        exit 1
    }
}
# }}}

# {{{ run_extract
run_extract() {
    log_stage "🔄 Stage 2/10: Extracting content from backup archives"

    # Issue 8-011/10-065: reshared-post inclusion, as an explicit yes or no. This
    # used to read a separate INCLUDE_BOOSTS boolean that the CLI could not
    # actually set (the flag's case branch was shadowed by an earlier duplicate),
    # so extraction silently used config.privacy.include_boosts no matter what
    # was typed. One required flag now feeds both this stage and parsing.
    local boost_flag="--no-boosts"
    if [ "$BOOSTS" = "yes" ]; then
        boost_flag="--include-boosts"
    fi

    if $DRY_RUN; then
        log_dry_run "$DIR/scripts/update $DIR $boost_flag"
        return 0
    fi

    "$DIR/scripts/update" "$DIR" $boost_flag || {
        echo "Error: Content extraction failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_strip_excluded
# Issue 10-053: After sync/extraction, remove excluded images + note source files
# from input/ so they are never cataloged, embedded, rendered, or uploaded. Runs
# before image cataloging. strip-excluded validates every exclusion BEFORE it
# deletes anything; a non-zero exit means a broken exclusion path (it points at no
# real file), which is FATAL -- continuing would ship content that was explicitly
# marked do-not-ship. The validation happens before any stripping and before the
# expensive catalog/embed stages, so a bad path costs only the cheap re-run.
run_strip_excluded() {
    log_stage "🧹 Stripping excluded content from input/"
    if $DRY_RUN; then
        log_dry_run "lua $DIR/scripts/strip-excluded $DIR"
        return 0
    fi
    if ! lua "$DIR/scripts/strip-excluded" "$DIR"; then
        echo "ERROR: strip-excluded failed -- a broken exclusion path in config.lua." >&2
        echo "       Fix excluded_images and re-run; nothing was stripped or shipped." >&2
        exit 1
    fi
}
# }}}

# {{{ run_parse
run_parse() {
    log_stage "📝 Stage 3/10: Parsing poems from JSON sources"

    # Issue 10-016: Check both global and per-stage force flags (Stage 3)
    local stage_force=$FORCE
    $FORCE_STAGE_3 && stage_force=true

    local force_arg=""
    if $stage_force; then
        force_arg="--force"
    fi

    # Issue 10-065: the same explicit yes/no extraction used, so the two stages
    # cannot disagree about what a poem is. main.lua understands both spellings.
    local boosts_arg="--no-boosts"
    if [ "$BOOSTS" = "yes" ]; then
        boosts_arg="--include-boosts"
    fi

    if $DRY_RUN; then
        log_dry_run "luajit src/main.lua $DIR --parse-only $force_arg $boosts_arg $ASSETS_ARG"
        return 0
    fi

    luajit src/main.lua "$DIR" --parse-only $force_arg $boosts_arg $ASSETS_ARG || {
        echo "Error: Poem parsing failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_validate
run_validate() {
    log_stage "$(symbol_success "✓") Stage 4/10: Validating poem data"

    if $DRY_RUN; then
        log_dry_run "luajit src/main.lua $DIR --validate-only $ASSETS_ARG"
        return 0
    fi

    luajit src/main.lua "$DIR" --validate-only $ASSETS_ARG || {
        echo "Error: Poem validation failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_catalog_images
# Issue 10-015a: Pass --verbose flag to show detailed image catalog statistics
run_catalog_images() {
    log_stage "🖼️ Stage 5/10: Cataloging images"

    # Build verbose argument if enabled
    local VERBOSE_ARG=""
    $VERBOSE && VERBOSE_ARG="--verbose"

    if $DRY_RUN; then
        log_dry_run "luajit src/main.lua $DIR --catalog-only $VERBOSE_ARG $ASSETS_ARG $RANDOM_SEED_ARG"
        return 0
    fi

    luajit src/main.lua "$DIR" --catalog-only $VERBOSE_ARG $ASSETS_ARG $RANDOM_SEED_ARG || {
        echo "Error: Image cataloging failed" >&2
        exit 1
    }
}
# }}}

# {{{ emb_cache_dir
# Issue 10-054: resolve a model's cache directory through the shared resolver
# (scripts/cache-dir), so run.sh's freshness/pre-flight checks look in EXACTLY the
# place the Lua code and generate-embeddings.sh write -- disk or RAM, per the
# CACHE_IN_RAM switch. Pass --disk for the reboot-surviving diversity cache. A
# blank result is a hard error rather than a silently-wrong (empty) path.
emb_cache_dir() {
    local d
    d="$(luajit "$DIR/scripts/cache-dir" "$DIR" --model "$MODEL_NAME" "$@")"
    if [ -z "$d" ]; then
        echo "Error: could not resolve cache dir (scripts/cache-dir)" >&2
        exit 1
    fi
    echo "$d"
}
# }}}

# {{{ require_embeddings_for_model()
# Issue 10-065 (open question 1): the check stages 7 and 8 already perform, given
# to stages 9 and 10, which lacked it.
#
# Why the disk is the right authority here. For stages 7-10 the model name is
# purely a CACHE DIRECTORY name -- they never contact the inference server. So
# the argument inference-server-config makes for refusing to validate --model
# (the server is the only authority on what is loaded, and a second authority
# drifts) simply does not reach them: there is no server in the loop to reject
# anything. What these stages actually need is embeddings on disk, and that is a
# thing this script can verify without keeping a second list in sync.
#
# What it prevents: a one-character slip. "--model qwen3-embedding:4B" resolves
# to a real, empty directory sitting beside the real ":4b" one, indistinguishable
# from a model whose embeddings have simply not been generated yet -- and stages
# 9 and 10 would then build a site against nothing.
#
# Called BEFORE each stage's dry-run check, matching stages 7 and 8: a dry run
# should say that the real run cannot work. The check only reads, so it is safe
# there.
require_embeddings_for_model() {
    local stage_label="$1"
    local embeddings_file
    embeddings_file="$(emb_cache_dir)/embeddings.json"
    if [ -f "$embeddings_file" ]; then
        return 0
    fi

    echo "Error: no embeddings for model '$MODEL_NAME' (needed by $stage_label)" >&2
    echo "       Looked for: $embeddings_file" >&2

    # List what IS present, so a typo is visible by comparison. These are
    # DIRECTORY names, not model names: the mapping writes ':' as '_' and cannot
    # be reversed unambiguously (a model could contain a literal underscore), so
    # showing the directory and saying how it was spelled is the honest form.
    local root
    root="$(dirname "$(emb_cache_dir)")"
    local found=()
    local d
    for d in "$root"/*/; do
        [ -f "$d/embeddings.json" ] || continue
        found+=("$(basename "$d")")
    done

    if [ "${#found[@]}" -gt 0 ]; then
        echo "       Models with embeddings on disk (directory names; ':' is written '_'):" >&2
        local m
        for m in "${found[@]}"; do
            echo "         $m" >&2
        done
    else
        echo "       No model has embeddings yet. Run --generate-embeddings first." >&2
    fi
    exit 1
}
# }}}

# {{{ run_generate_embeddings
run_generate_embeddings() {
    log_stage "🤖 Stage 6/10: Generating embeddings via the inference server"

    # Convert model name for directory (embeddinggemma:latest -> embeddinggemma_latest)
    local model_dir_name="${MODEL_NAME//:/_}"
    local embeddings_file="$(emb_cache_dir)/embeddings.json"
    # Issue 10-065: built from the resolved assets directory, not a hardcoded
    # "$DIR/assets". When --dir pointed the child programs at another corpus,
    # this freshness check went on reading the original one -- so the count it
    # compared against was from a different set of poems entirely.
    local poems_file="$ASSETS_DIR/poems.json"

    # Issue 10-016: Check both global and per-stage force flags
    local stage_force=$FORCE
    $FORCE_STAGE_6 && stage_force=true

    # Freshness check (Issue 10-050): skip ONLY when every poem already has an
    # embedding. The old test compared mtimes (embeddings.json newer than
    # poems.json) — which was wrong: a run that embedded 8160/8362 and then died
    # leaves a NEWER but INCOMPLETE embeddings.json, so mtime said "fresh, skip"
    # and the missing poems never got done. Counting entries is the honest
    # signal; incremental mode then fills only the gap, so it is cheap to re-run.
    if ! $stage_force && [ -f "$embeddings_file" ] && [ -f "$poems_file" ]; then
        # Count embeddings WITHOUT parsing the (large) JSON: each entry carries
        # exactly one "poem_index" key. (This counts error records too, so it can
        # only over-report completeness; incremental retries those anyway.)
        local emb_count
        emb_count=$(grep -o '"poem_index"' "$embeddings_file" | wc -l)
        local poem_count
        # Issue 10-065: `#(d.poems or d)` used to stand here -- "the poems field,
        # or else treat the whole document as the list". That absorbed a change
        # in the file's shape instead of reporting one, and the consequence was
        # not an error but a NUMBER: a wrong count, silently compared against the
        # embeddings, deciding whether to skip a 2-3 hour stage.
        poem_count=$(luajit -e "
            package.path = '$DIR/?.lua;' .. package.path
            local dk = require('libs/dkjson')
            local f = io.open('$poems_file')
            if not f then error('cannot open $poems_file') end
            local d = dk.decode(f:read('*a')); f:close()
            if type(d) ~= 'table' or type(d.poems) ~= 'table' then
                error('$poems_file has no poems array; cannot count the corpus')
            end
            print(#d.poems)
        ")
        if [ -z "$poem_count" ]; then
            echo "Error: could not count poems in $poems_file" >&2
            echo "       Without a corpus size there is no way to tell a complete" >&2
            echo "       embeddings file from an interrupted one." >&2
            exit 1
        fi
        if [ "$poem_count" -gt 0 ] && [ "$emb_count" -ge "$poem_count" ]; then
            log_info "   ⏭️  Embeddings complete ($emb_count/$poem_count), skipping..."
            return 0
        fi
        log_info "   Embeddings incomplete ($emb_count/$poem_count) — running incremental to fill the gap..."
    fi

    local force_arg=""
    if $stage_force; then
        force_arg="--full-regen"
    else
        force_arg="--incremental"
    fi

    # Issue 10-017/10-065: the server is required for this stage, so the flag is
    # built unconditionally. It used to be omitted when INFERENCE_SERVER was
    # empty, which handed the choice to config.default_inference_server -- and
    # the log line below was likewise conditional, so the run did not even say
    # which endpoint it had spent the whole stage talking to.
    local server_arg="--server=$INFERENCE_SERVER"

    if $DRY_RUN; then
        log_dry_run "$DIR/generate-embeddings.sh $force_arg --model=$MODEL_NAME $server_arg $DIR"
        log_dry_run "luajit $DIR/src/generate-word-pages.lua $DIR --embeddings-only $ASSETS_ARG"
        return 0
    fi

    log_info "   Inference Server: $INFERENCE_SERVER"
    log_info "   Model: $MODEL_NAME"
    log_info "   Output: assets/embeddings/$model_dir_name/embeddings.json"
    log_info "   Mode: $(if $FORCE; then echo 'full regeneration'; else echo 'incremental (skip existing)'; fi)"

    # Issue 10-028: Apply low priority to expensive embedding generation
    $NICE_PREFIX "$DIR/generate-embeddings.sh" $force_arg --model="$MODEL_NAME" $server_arg "$DIR" || {
        echo "Error: Embedding generation failed" >&2
        echo "Make sure the inference server is running with the $MODEL_NAME model" >&2
        exit 1
    }

    # Word embeddings used to run here, but the word-COLOR step inside
    # generate-word-pages needs color_embeddings.json, which is produced later by
    # run_generate_semantic_colors. Running words first made that step skip with
    # "no color embeddings found". Moved to run_generate_word_embeddings, called
    # AFTER colors in main.
}
# }}}

# {{{ run_generate_word_embeddings
# Word-cloud word embeddings + their semantic colors. Split out of
# run_generate_embeddings (Issue 8-043b) and ordered AFTER the semantic-color
# stage so color_embeddings.json already exists when the word-color step runs.
run_generate_word_embeddings() {
    log_info "   Generating word embeddings for word cloud..."
    # WORDCLOUD_WORDS carries either a number or the literal "all"; the generator
    # accepts both via --words (it treats "--words all" the same as "--all").
    # Issue 10-065: passed unconditionally -- the value is required by this stage,
    # so there is no "omit the flag and let the generator pick a count" case.
    local wordcloud_args="--words $WORDCLOUD_WORDS"

    # Issue 10-065: this was the ONLY stage function with no dry-run guard, found
    # by auditing all fourteen of them after two others turned up with the guard
    # in the wrong PLACE. It is the worst of the three: the others touched local
    # files, while this one opened a network connection to the inference server
    # and began embedding -- so `--dry-run` did real work on another machine.
    if $DRY_RUN; then
        log_dry_run "luajit $DIR/src/generate-word-pages.lua $DIR --embeddings-only $wordcloud_args $ASSETS_ARG"
        return 0
    fi

    # Issue 10-065: was a warning that continued. Word embeddings are what the
    # per-word similarity pages rank against, so continuing meant stage 10 would
    # later build its pages from whatever stale embeddings were lying around --
    # and produce a complete-looking word cloud whose rankings answer a question
    # nobody asked on this run.
    $NICE_PREFIX luajit "$DIR/src/generate-word-pages.lua" "$DIR" --embeddings-only $wordcloud_args $ASSETS_ARG || {
        echo "Error: word embedding generation failed" >&2
        echo "       The per-word similarity pages rank against these embeddings;" >&2
        echo "       continuing would build stage 10 from stale ones." >&2
        exit 1
    }
}
# }}}

# {{{ run_generate_semantic_colors
run_generate_semantic_colors() {
    # Regenerate poem_colors.json if stale or missing
    # This runs BEFORE similarity matrix generation (Stage 6.5)
    # Requires: embeddings.json, color_embeddings.json
    # Respects: --force (skip freshness check), --dry-run (show actions only)

    local model_dir_name="${MODEL_NAME//:/_}"

    # Paths match what generate-embeddings.sh writes (see run_generate_embeddings above).
    # The stray assets/embeddings/embeddings/ directory on disk is a stale leftover from
    # before the model-name subfolder convention; it is not the real output location.
    local embeddings_file="$(emb_cache_dir)/embeddings.json"
    local poem_colors_file="$(emb_cache_dir)/poem_colors.json"
    local color_embeddings_file="$(emb_cache_dir)/color_embeddings.json"

    # Issue 10-065: this used to log at VERBOSE level and return success. That is
    # the quietest failure in the script: this function only ever runs as part of
    # stage 6, immediately after the stage that writes embeddings.json -- so the
    # file being absent means that stage did not do its job, and the run reported
    # a clean pipeline having skipped a stage. At default verbosity the message
    # was not even printed.
    if [ ! -f "$embeddings_file" ]; then
        echo "Error: embeddings not found: $embeddings_file" >&2
        echo "       Semantic colours run as part of stage 6, right after the step" >&2
        echo "       that writes this file, so its absence means that step failed." >&2
        exit 1
    fi

    # color_embeddings.json is derived from the color palette (color_names +
    # color_associations in config.lua). It used to regenerate ONLY when the file was
    # missing, so editing the palette -- e.g. dropping gray as a cluster color -- had
    # no effect until someone deleted the cache by hand (and the config comment that
    # said "re-run stage 6.5 after editing" was quietly false). We now fingerprint the
    # palette and regenerate whenever it changes, so editing colors then re-running
    # actually takes effect. The fingerprint is a sorted, deterministic dump of the
    # palette -- no server needed to compute it.
    local palette_fp_file="$(emb_cache_dir)/color_palette.fingerprint"
    local current_palette_fp
    # Issue 10-065: the empty-table stand-ins here (`config.color_names or {}`,
    # `(config.color_associations or {})[n] or {}`) were quietly load-bearing. A
    # config with no palette fingerprinted to the SAME empty string as a config
    # whose palette had simply not changed -- so a broken config read as "still
    # fresh, skip", and the colour cache was never rebuilt. A fingerprint whose
    # failure mode is a valid-looking value is worse than no fingerprint.
    current_palette_fp=$(luajit -e "
        package.path = '$DIR/libs/?.lua;$DIR/src/?.lua;' .. package.path
        local config = require('config-loader').load()
        if type(config.color_names) ~= 'table' or #config.color_names == 0 then
            error('config.lua has no color_names; the semantic-colour palette is empty')
        end
        if type(config.color_associations) ~= 'table' then
            error('config.lua has no color_associations table')
        end
        local names = {}
        for _, n in ipairs(config.color_names) do names[#names+1] = n end
        table.sort(names)
        local parts = {}
        for _, n in ipairs(names) do
            local assoc = config.color_associations[n]
            if type(assoc) ~= 'table' then
                error('color_associations has no entry for the colour ' .. n)
            end
            local a = {}
            for _, w in ipairs(assoc) do a[#a+1] = w end
            table.sort(a)
            parts[#parts+1] = n .. '=' .. table.concat(a, ',')
        end
        io.write(table.concat(parts, '|'))
    ") || {
        echo "Error: could not fingerprint the colour palette from config.lua" >&2
        exit 1
    }
    if [ -z "$current_palette_fp" ]; then
        echo "Error: colour palette fingerprint came back empty" >&2
        exit 1
    fi
    local stored_palette_fp=""
    [ -f "$palette_fp_file" ] && stored_palette_fp=$(cat "$palette_fp_file")

    # Regenerate color embeddings if missing OR the palette changed since last time.
    if [ ! -f "$color_embeddings_file" ] || [ "$current_palette_fp" != "$stored_palette_fp" ]; then
        if [ -f "$color_embeddings_file" ]; then
            log_stage "🎨 Stage 6.5/10: Color palette changed -- regenerating color embeddings"
        else
            log_stage "🎨 Stage 6.5/10: Generating color embeddings (one-time)"
        fi

        if $DRY_RUN; then
            log_dry_run "luajit semantic-color-calculator (generate color embeddings)"
            # Still need to skip poem colors generation in dry run
        else
            log_info "   $(symbol_warning "⚠️")  Color embeddings not found, generating via the inference server..."
            # Issue 10-003 migrated color_names from config/semantic-colors.json (now deleted)
            # into config.lua, loaded via libs/config-loader.lua. Errors here are loud rather
            # than silent so a missing config doesn't propagate downstream as a confusing
            # "Failed to load required data files" in the next stage.
            luajit -e "
                package.path = '$DIR/libs/?.lua;$DIR/src/?.lua;' .. package.path
                local calc = require('semantic-color-calculator')
                local utils = require('utils')
                -- Issue 10-065: '--dir', PATH -- not a bare positional. This read
                -- init_assets_root({'\$DIR'}), and utils.parse_assets_dir only
                -- recognizes '--dir PATH' or '--dir=PATH', so a lone positional
                -- was DISCARDED and the block fell through to the project's own
                -- assets directory. It happened to be the same path, which is why
                -- it went unnoticed -- until --dir pointed somewhere else, and
                -- then this block silently read a different corpus than the
                -- stage that launched it.
                utils.init_assets_root({'--dir', '$ASSETS_DIR'})

                -- Issue 10-065: the server is set unconditionally now. It used to
                -- be guarded by a non-empty test on INFERENCE_SERVER, and an
                -- empty one meant the module quietly used config.lua's
                -- default_inference_server -- so a colour palette could be
                -- embedded against a different endpoint than the poems were.
                -- The interactive flag is forwarded so that a typoed --server or
                -- --model triggers a 1/2 prompt only when the operator launched
                -- run.sh with -I; otherwise we hard-error.
                local inference = require('inference-server-config')
                inference.set_project_root('$DIR')
                inference.set_interactive_mode('$INTERACTIVE' == 'true')
                inference.set_selected_server('$INFERENCE_SERVER')

                local config = require('config-loader').load()
                if not config.color_names then
                    error('config.lua is missing color_names (Issue 10-003 migration)')
                end
                if type(config.color_associations) ~= 'table' then
                    error('config.lua is missing color_associations; each colour embedding '
                          .. 'is the mean of its essence words, and without them the '
                          .. 'calculator would silently embed the bare colour word instead')
                end
                -- Pass color_associations so each color's embedding is the mean
                -- of its essence words, not the bare color word (richer + the
                -- z-scored assignment is balanced). nil endpoint = use the
                -- selected server. Issue 10-065 added the check above: the
                -- calculator's own bare-word fallback is still there, but it can
                -- no longer be reached from here without anyone noticing.
                local embeddings = calc.generate_color_embeddings(config.color_names, '$MODEL_NAME', nil, config.color_associations)
                if not next(embeddings) then
                    error('Inference server returned no color embeddings')
                end
                local data = {embeddings = embeddings, generated_at = os.date('%Y-%m-%d %H:%M:%S'), model_name = '$MODEL_NAME'}
                utils.write_json_file('$color_embeddings_file', data)
                print('[INFO] Color embeddings saved: ' .. '$color_embeddings_file')
            " || {
                echo "Error: Color embedding generation failed" >&2
                exit 1
            }
            # Remember the palette we just built from, so the next run can tell
            # whether it changed (and skip this server round-trip when it hasn't).
            echo "$current_palette_fp" > "$palette_fp_file"
        fi
    fi

    # Issue 10-016: Check both global and per-stage force flags (Stage 6)
    local stage_force=$FORCE
    $FORCE_STAGE_6 && stage_force=true

    # Check freshness: poem_colors.json should be newer than embeddings.json
    # With --force or --force-stage 6: always regenerate regardless of freshness
    if ! $stage_force && [ -f "$poem_colors_file" ] && [ -f "$embeddings_file" ]; then
        # Poem colors depend on BOTH the poem embeddings AND the color centroids, so
        # they are only fresh when newer than both. Watching only embeddings.json
        # meant a palette change (which rewrites color_embeddings.json but not
        # embeddings.json) left poem_colors.json stale yet considered "fresh".
        if [ "$poem_colors_file" -nt "$embeddings_file" ] && [ "$poem_colors_file" -nt "$color_embeddings_file" ]; then
            log_info "   ⏭️  Semantic colors are fresh (newer than embeddings + palette), skipping..."
            return 0
        fi
        log_verbose "   poem_colors.json is stale (older than embeddings or palette), regenerating..."
    elif $stage_force; then
        log_verbose "   --force specified, regenerating semantic colors..."
    fi

    log_stage "🎨 Stage 6b/10: Computing semantic colors (part of embeddings)"

    if $DRY_RUN; then
        log_dry_run "luajit semantic-color-calculator (poem colors regeneration)"
        return 0
    fi

    log_info "   Input: $embeddings_file"
    log_info "   Output: $poem_colors_file"

    # Regenerate poem colors using existing embeddings
    luajit -e "
        package.path = '$DIR/libs/?.lua;$DIR/src/?.lua;' .. package.path
        local calc = require('semantic-color-calculator')
        local utils = require('utils')
        utils.init_assets_root({'--dir', '$ASSETS_DIR'})

        local poems_data = utils.read_json_file(utils.asset_path('poems.json'))
        local embeddings_data = utils.read_json_file('$embeddings_file')
        local color_embeddings_data = utils.read_json_file('$color_embeddings_file')

        if poems_data and embeddings_data and color_embeddings_data then
            calc.precompute_poem_colors(poems_data, embeddings_data, color_embeddings_data.embeddings, '$poem_colors_file')
        else
            error('Failed to load required data files')
        end
    " || {
        echo "Error: Semantic color generation failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_augment_images
# Issue 9-013: give every text-less image a pseudo-embedding (the normalized
# average of the poem before and after it chronologically) and fold those into
# embeddings.json so the GPU similarity stage ranks images alongside poems.
# Also writes image-manifest.json, which the HTML renderer reads to draw image
# entries. Cheap and idempotent, so it runs each time before the matrix build.
run_augment_images() {
    log_stage "🖼️  Stage 6.7: Folding images into the embedding set (pseudo-embeddings)"
    local model_dir_name="${MODEL_NAME//:/_}"
    local embeddings_file="$(emb_cache_dir)/embeddings.json"
    if [ ! -f "$embeddings_file" ]; then
        echo "Error: embeddings.json not found; run --generate-embeddings first" >&2
        exit 1
    fi
    if $DRY_RUN; then
        log_dry_run "luajit $DIR/src/augment-embeddings-with-images.lua $DIR"
        return 0
    fi
    $NICE_PREFIX luajit "$DIR/src/augment-embeddings-with-images.lua" "$DIR" || {
        echo "Error: image augmentation failed" >&2
        exit 1
    }
}
# }}}

# {{{ run_generate_similarity
run_generate_similarity() {
    # GPU (Vulkan) is required: these are O(N^2) similarity calculations that make no
    # sense on a CPU, so the CPU route was removed (Issue 10-057). A missing GPU library
    # is a hard error with build instructions, never a slow fallback.
    if [ ! -f "$DIR/libs/vulkan-compute/build/libvkcompute.so" ]; then
        echo "Error: GPU library not found: libs/vulkan-compute/build/libvkcompute.so" >&2
        echo "Build it: cd libs/vulkan-compute && make" >&2
        exit 1
    fi
    log_stage "📊 Stage 7/10: Building similarity matrix with GPU"

    # Convert model name for directory
    local model_dir_name="${MODEL_NAME//:/_}"
    local embeddings_file="$(emb_cache_dir)/embeddings.json"

    # Check if embeddings exist
    if [ ! -f "$embeddings_file" ]; then
        echo "Error: Embeddings file not found: $embeddings_file" >&2
        echo "Run --generate-embeddings first" >&2
        exit 1
    fi

    # Issue 10-016: Check both global and per-stage force flags (Stage 7)
    local stage_force=$FORCE
    $FORCE_STAGE_7 && stage_force=true

    # Issue 8-033: Check for individual similarity files instead of monolithic matrix
    local similarities_dir="$(emb_cache_dir)/similarities"
    local similarity_count=0
    if [ -d "$similarities_dir" ]; then
        # Issue 10-065: no 2>/dev/null here. The directory's existence is already
        # checked above, so anything find still complains about (an unreadable
        # subdirectory, say) would make this count too LOW -- and a count that is
        # too low reads as "cache incomplete, rebuild it", quietly turning a
        # permissions problem into a multi-hour regeneration.
        similarity_count=$(find "$similarities_dir" -name "poem_*.json" | wc -l)
    fi

    # How many similarity files SHOULD exist: exactly one per embedding. The
    # embeddings file is the only thing that knows, so it is what we ask.
    #
    # Issue 10-065: this used to be the literal 7797. Two things were wrong with
    # it, and the second is why a number could not be made to work here at all.
    #
    #   It was already stale. The real count is one per EMBEDDING, and the
    #   embedding set includes the image pseudo-embeddings folded in by stage 6.7
    #   (Issue 9-013) -- 8701 against 8050 poems when this was written. So a run
    #   that died after 7900 files cleared a 7797 threshold and was called
    #   complete, leaving ~800 entries with no similarity data for the HTML stage
    #   to build pages from.
    #
    #   It goes stale continuously. The corpus grows every time a poem is
    #   written, so any constant here is correct only until the next poem.
    #
    # This is the same defect Issue 10-050 fixed one stage earlier, where an
    # mtime comparison called an interrupted embeddings.json fresh. The lesson it
    # recorded -- "counting entries is the honest signal" -- simply had not been
    # carried into stage 7. Counting the embeddings costs one grep over a file
    # this stage is about to read in full anyway.
    local expected_count
    expected_count=$(grep -o '"poem_index"' "$embeddings_file" | wc -l)
    if [ -z "$expected_count" ] || [ "$expected_count" -eq 0 ]; then
        echo "Error: $embeddings_file contains no embeddings" >&2
        echo "       Without a count there is no way to tell a complete similarity" >&2
        echo "       cache from an interrupted one. Re-run --generate-embeddings." >&2
        exit 1
    fi

    # Freshness check: skip only when every embedding has a similarity file AND
    # those files are newer than the embeddings they were computed from.
    if ! $stage_force && [ "$similarity_count" -ge "$expected_count" ]; then
        # Check if any are older than embeddings (check newest file)
        local newest_similarity=$(find "$similarities_dir" -name "poem_*.json" -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)
        if [ -n "$newest_similarity" ] && [ "$newest_similarity" -nt "$embeddings_file" ]; then
            log_info "   ⏭️  Similarity files are fresh ($similarity_count/$expected_count, newer than embeddings), skipping..."
            return 0
        fi
    elif ! $stage_force && [ "$similarity_count" -gt 0 ]; then
        # Say the count out loud. An interrupted cache used to be indistinguishable
        # from a complete one in the log; now the shortfall is on screen.
        log_info "   Similarity cache incomplete ($similarity_count/$expected_count) — rebuilding..."
    fi

    # Issue 10-065: unconditional. --threads is required by this stage.
    local threads_arg="--threads=$THREADS"

    if $DRY_RUN; then
        log_dry_run "luajit (GPU vk_similarity via libvkcompute.so) --generate-matrix $threads_arg"
        return 0
    fi

    log_info "   Input: assets/embeddings/$model_dir_name/embeddings.json"
    log_info "   Output: assets/embeddings/$model_dir_name/similarities/*.json (individual files)"

    # Issue 10-016: Convert stage_force to Lua boolean for Lua function calls
    local stage_force_lua="false"
    $stage_force && stage_force_lua="true"

    # GPU similarity generation using Vulkan compute shaders (the only route now)
        log_info "   Mode: GPU-accelerated (Vulkan)"

        # Issue 10-065: the literal 8 that used to stand in here is gone. It was
        # the most concrete example of the problem: a number written into the
        # source of one stage, disagreeing with the "(default: 4)" the help text
        # advertised, and with whatever the HTML stage's child picked for itself.
        log_info "   CPU sorting threads: $THREADS"

        DIR="$DIR" luajit -e "
            package.path = '$DIR/?.lua;$DIR/?/init.lua;$DIR/libs/?.lua;' .. package.path
            local vk_sim = require('libs.vulkan-compute.lua.vk_similarity')
            -- Issue 10-057: size the rankings cache to exactly what THIS build shows
            -- per poem -- the ACTUAL pages it generates times the poems shown per
            -- page -- NOT the storage ceiling max_pages_per_poem. The list is sorted
            -- nearest-first, so the top-K ARE precisely what the pages display. The
            -- HTML stage's loader regenerates if a later run needs more (the top_k
            -- stamp makes that detectable).
            --
            -- Issue 10-065: both numbers come from the command line and nowhere
            -- else. They used to read 'the --pages value, or else
            -- config.pagination.minimum_pages' -- and that mattered more here
            -- than it looks, because THIS number decides how much of the
            -- similarity cache gets built, while stage 9 separately decides how
            -- much of it to display. Two stages resolving the same value through
            -- different fallbacks is how a cache ends up one page short of the
            -- pages that read it.
            local _pages = tonumber('$PAGES')
            local _per_page = tonumber('$POEMS_PER_PAGE')
            if not _pages then error('--pages is not a number: $PAGES') end
            if not _per_page then error('--poems-per-page is not a number: $POEMS_PER_PAGE') end
            local _top_k = _pages * _per_page
            -- Use TRUE parallel GPU computation (Issue 9-002 original design)
            local success = vk_sim.generate_similarity_matrix_gpu_parallel(
                '$(emb_cache_dir)/embeddings.json',
                '$MODEL_NAME',
                $stage_force_lua,
                $THREADS,
                _top_k
            )
            if not success then
                print('[GPU SIMILARITY ERROR] GPU generation failed')
                os.exit(1)
            end
        " || {
            echo "Error: GPU similarity generation failed" >&2
            exit 1
        }

    # Note: Pre-sorted similarity rankings cache is now generated automatically
    # by the GPU similarity engine (in-RAM, no file re-reading needed)
}
# }}}

# {{{ run_generate_diversity
run_generate_diversity() {
    # GPU (Vulkan) is required: the diversity walk is O(N^2) GPU work, so the CPU route
    # was removed (Issue 10-057). A missing GPU library is a hard error, not a fallback.
    if [ ! -f "$DIR/libs/vulkan-compute/build/libvkcompute.so" ]; then
        echo "Error: GPU library not found: libs/vulkan-compute/build/libvkcompute.so" >&2
        echo "Build it: cd libs/vulkan-compute && make" >&2
        exit 1
    fi
    log_stage "🎲 Stage 8/10: Pre-computing diversity cache with GPU"

    # Convert model name for directory
    local model_dir_name="${MODEL_NAME//:/_}"
    local cache_file="$(emb_cache_dir --disk)/diversity_cache.json"
    local embeddings_file="$(emb_cache_dir)/embeddings.json"

    # Check if embeddings exist
    if [ ! -f "$embeddings_file" ]; then
        echo "Error: Embeddings file not found: $embeddings_file" >&2
        echo "Run --generate-embeddings first" >&2
        exit 1
    fi

    # Issue 10-016: Check both global and per-stage force flags (Stage 8)
    local stage_force=$FORCE
    $FORCE_STAGE_8 && stage_force=true

    # Freshness check: skip if cache newer than embeddings
    if ! $stage_force && [ -f "$cache_file" ]; then
        if [ "$cache_file" -nt "$embeddings_file" ]; then
            log_info "   ⏭️  Diversity cache is fresh (newer than embeddings), skipping..."
            return 0
        fi
    fi

    log_info "   Input: assets/embeddings/$model_dir_name/embeddings.json"
    log_info "   Output: assets/embeddings/$model_dir_name/diversity_cache.json"

    # GPU diversity generation using Vulkan compute shaders (the only route now)
        log_info "   Mode: GPU-accelerated (Vulkan)"

        if $DRY_RUN; then
            log_dry_run "$DIR/scripts/precompute-diversity-sequences-gpu $DIR"
            return 0
        fi

        # Issue 10-028: Apply low priority to expensive diversity generation.
        # The model is not passed via env here: the wrapper resolves it through
        # inference-server-config, which reads this run's overrides notepad
        # (tmp/shared-memory/run-overrides.lua). Issue 10-065: that notepad now
        # always carries a model, because --model is required -- so the sentence
        # that used to end this comment ("and falls back to config.lua") no
        # longer describes anything that can happen.
        # Issue 10-057: pass the run's page settings so the wrapper caps each diversity
        # sequence to the SAME K the similarity cache and the HTML stage use.
        PAGES="$PAGES" POEMS_PER_PAGE="$POEMS_PER_PAGE" $NICE_PREFIX "$DIR/scripts/precompute-diversity-sequences-gpu" "$DIR" || {
            echo "Error: GPU diversity cache generation failed" >&2
            exit 1
        }
}
# }}}

# {{{ run_generate_html
run_generate_html() {
    log_stage "🌐 Stage 9/10: Generating website HTML"

    # Issue 10-065: this stage reads the model's caches (through the run-overrides
    # notepad) but never contacts a server, so nothing else here would catch a
    # mistyped --model. See require_embeddings_for_model.
    require_embeddings_for_model "stage 9 (generate-html)"

    # Issue 10-016: Check both global and per-stage force flags (Stage 9)
    local stage_force=$FORCE
    $FORCE_STAGE_9 && stage_force=true

    local force_arg=""
    if $stage_force; then
        force_arg="--force"
    fi

    # Issue 10-065: every one of these was a conditional that omitted the flag
    # when the value was empty, handing the decision to the child program. Four
    # separate places where the command line could quietly stop mattering. All
    # four values are required by this stage, so all four are always passed --
    # which also means the --dry-run output below now shows the complete,
    # runnable command rather than an abridged one.
    local threads_arg="--threads $THREADS"
    local pages_arg="--pages $PAGES"
    local poems_per_page_arg="--poems-per-page $POEMS_PER_PAGE"
    local chrono_per_page_arg="--chrono-per-page $CHRONO_PER_PAGE"

    # Same ordering rule as the word-cloud stage: the dry-run check comes before
    # the clear below, because --dry-run must not delete anything. This stage's
    # clear is guarded by --force, so it took BOTH flags to trigger -- which made
    # it rarer than the word-cloud one and no less destructive when it fired.
    if $DRY_RUN; then
        if $stage_force; then
            log_dry_run "rm $OUTPUT_DIR/{similar,different,chronological}/*.html (clear stale pages, --force)"
        fi
        log_dry_run "$DIR/scripts/sync-page-templates $DIR (restore explore-page copy into input/pages/)"
        log_dry_run "luajit src/main.lua $DIR --html-only $force_arg $threads_arg $pages_arg $poems_per_page_arg $chrono_per_page_arg $ASSETS_ARG"
        log_dry_run "luajit $DIR/src/generate-gallery-pages.lua $DIR $ASSETS_ARG"
        log_dry_run "luajit $DIR/src/generate-source-browser.lua $DIR"
        return 0
    fi

    # Issue 10-024: Clear output directories when forcing regeneration.
    # This prevents stale files with obsolete poem_index values from persisting
    # after poem re-extraction changes the poem_index assignments.
    # Issue 10-065: the 2>/dev/null that used to hide these was suppressing the
    # one thing worth knowing -- that the clear did not happen. A glob matching
    # nothing is fine and silent anyway; a permission error is not.
    if $stage_force; then
        log_info "   Clearing stale HTML files (--force)..."
        rm -f "$OUTPUT_DIR/similar/"*.html
        rm -f "$OUTPUT_DIR/different/"*.html
        rm -f "$OUTPUT_DIR/chronological/"*.html
    fi

    # Issue 11-005: restore the authored explore-page copy into the ephemeral
    # input/pages/ before generating. The canonical, version-controlled source is
    # page-templates/*.txt; input/ is wiped + re-synced from external sources each
    # run and does NOT carry this prose, so it is copied back in here. (Edit the
    # files in page-templates/ -- input/pages/ is overwritten from them.)
    "$DIR/scripts/sync-page-templates" "$DIR" || {
        echo "Error: failed to restore page templates into input/pages/" >&2
        exit 1
    }

    # Issue 10-028: Apply low priority to HTML generation (parallel processing)
    $NICE_PREFIX luajit src/main.lua "$DIR" --html-only $force_arg $threads_arg $pages_arg $poems_per_page_arg $chrono_per_page_arg $ASSETS_ARG || {
        echo "Error: HTML generation failed" >&2
        exit 1
    }

    # Issue 10-059: the word-cloud menu and per-word similarity pages moved to their
    # own stage 10 (run_generate_wordcloud). They run after this stage, so the
    # chronological pages main.lua just built are already present for their #poem links.

    # Issue 10-042: Build the image gallery (masonry pages per source + index +
    # chronological). It was previously a separate manual step, so the gallery
    # went stale -- it now regenerates with every HTML run from image-catalog.json.
    # Issue 10-065: was a warning that continued. The gallery is linked from the
    # site's navigation whether or not it built, so continuing publishes a page
    # of broken links -- and the pipeline's final line still reads "completed
    # successfully", which is the part that makes it hard to catch.
    log_info "   Generating image gallery..."
    $NICE_PREFIX luajit "$DIR/src/generate-gallery-pages.lua" "$DIR" $ASSETS_ARG || {
        echo "Error: image gallery generation failed" >&2
        echo "       The site links to the gallery either way, so continuing" >&2
        echo "       would publish those links pointing at nothing." >&2
        exit 1
    }

    # Issue 10-052: Build the link-only source browser (code/issues/docs as HTML)
    # under output/source/. This is the "git push that builds a webpage" -- the
    # private monorepo never leaves the machine; whoever has the site link can
    # browse the source. It publishes an ALLOWLIST only (never the private input
    # corpus), so it is safe to ship with the rest of the site.
    # Issue 10-065: was a warning that continued. This one publishes source code
    # against an allowlist, so a partial run is not merely incomplete -- a
    # half-finished pass is the wrong thing to be relaxed about when the
    # question it answers is "which files leave this machine".
    log_info "   Generating source browser..."
    $NICE_PREFIX luajit "$DIR/src/generate-source-browser.lua" "$DIR" || {
        echo "Error: source browser generation failed" >&2
        echo "       This stage decides which source files are published, so a" >&2
        echo "       partial run is not something to continue past." >&2
        exit 1
    }
    # NOTE: the downloadable zip is built at POST time by running
    # scripts/build-download-zip directly, not here -- it is a deploy artifact, and
    # there is no point regenerating a multi-GB archive on every local build. (The
    # site's links are document-relative, so there is no URL-conversion step before
    # upload; just upload output/ and build the zip.)
}
# }}}

# {{{ run_generate_wordcloud
# Issue 10-059: the word-cloud stage. Builds the site's entry menu (which carries the
# live poem index) and the per-word similarity pages. Runs after stage 9, so the
# chronological pages its #poem links target already exist. Replaces the retired
# numeric-similarity-index stage, whose output (numeric-index.html) was linked from
# nowhere and was superseded by the menu's embedded poem index.
run_generate_wordcloud() {
    log_stage "🔤 Stage 10/10: Generating word-cloud menu and per-word pages"

    # Issue 10-065: same reasoning as stage 9. The per-word similarity pages rank
    # against this model's word embeddings, so a mistyped --model would rank
    # against an empty directory. See require_embeddings_for_model.
    require_embeddings_for_model "stage 10 (generate-wordcloud)"

    # Word-cloud arguments. WORDCLOUD_WORDS is a number or "all"; --words carries
    # either ("--words all" == every word, per the generators).
    # Issue 10-065: all three passed unconditionally. The chrono_per_page one is
    # the instructive case -- it exists (Issue 10-036) precisely so this stage
    # and stage 9 agree on how many poems fit a chronological page, and yet it
    # was OMITTED when empty, letting the two stages resolve it independently.
    # A flag whose entire purpose is agreement cannot be optional.
    local wordcloud_words_arg="--words $WORDCLOUD_WORDS"
    local wordcloud_poems_arg="--poems-per-page $WORDCLOUD_POEMS"
    local chrono_per_page_arg="--chrono-per-page $CHRONO_PER_PAGE"

    # The dry-run check comes BEFORE the clear below, and that ordering is a bug
    # fix, not a style choice: it used to come after, so --dry-run DELETED every
    # per-word page and then printed what it "would" do. Roughly 7,000 files and
    # 11 GB, removed by the one flag whose entire promise is that it changes
    # nothing. Any destructive step in a stage function belongs below this check.
    if $DRY_RUN; then
        log_dry_run "rm $OUTPUT_DIR/wordcloud/*.html (clear stale per-word pages)"
        log_dry_run "luajit $DIR/src/wordcloud-generator.lua $DIR $wordcloud_words_arg $chrono_per_page_arg $RANDOM_SEED_ARG $ASSETS_ARG"
        log_dry_run "luajit $DIR/src/generate-word-pages.lua $DIR --html-only $wordcloud_words_arg $wordcloud_poems_arg $chrono_per_page_arg $ASSETS_ARG"
        return 0
    fi

    # Issue 10-059/10-061: wipe the per-word pages before regenerating. A word that
    # has fallen out of the cloud since the last build leaves an orphan page that the
    # generator never overwrites -- and an orphan from before a link-scheme change
    # ships BROKEN links (this is exactly how 134 stale "/similar-different/" pages
    # survived into a relative-path build). The pages are fully regenerated from the
    # current word set just below, so clearing every run (not only on --force) is
    # safe and is the only way to guarantee no stale orphans. Matches the principle
    # that each stage wipes its own output subdirectory before rebuilding it.
    if [ -d "$OUTPUT_DIR/wordcloud" ]; then
        log_info "   Clearing stale per-word pages before regeneration..."
        rm -f "$OUTPUT_DIR/wordcloud/"*.html
    fi

    # Every generated page's stylesheet points at output/fonts/, so the font has
    # to be there before the pages that reference it are served. Fatal on failure:
    # a missing font file does not error in a browser, it silently falls back to
    # the device's own monospace -- which on a phone lacks the box-drawing
    # characters this entire layout is built from, and the frames shear apart.
    # A silent visual regression is exactly what the build should refuse to ship.
    log_info "   Installing site fonts..."
    "$DIR/scripts/install-fonts" "$DIR" || {
        echo "Error: font installation failed" >&2
        exit 1
    }

    # The word cloud IS the site's menu (and carries the live poem index), so a
    # failure here is fatal, not a warning -- there is no usable entry page without it.
    log_info "   Generating word cloud menu..."
    $NICE_PREFIX luajit "$DIR/src/wordcloud-generator.lua" "$DIR" $wordcloud_words_arg $chrono_per_page_arg $RANDOM_SEED_ARG $ASSETS_ARG || {
        echo "Error: Word cloud menu generation failed" >&2
        exit 1
    }

    log_info "   Generating word similarity pages..."
    $NICE_PREFIX luajit "$DIR/src/generate-word-pages.lua" "$DIR" --html-only $wordcloud_words_arg $wordcloud_poems_arg $chrono_per_page_arg $ASSETS_ARG || {
        echo "Error: Word similarity page generation failed" >&2
        exit 1
    }
}
# }}}

# }}}

# {{{ interactive_mode_tui
# TUI-based interactive mode with command preview
# Uses Lua menu library for stable rendering and real-time command preview
interactive_mode_tui() {
    # Issue 10-065: both of these used to fall back to a different, older
    # interactive mode (luajit src/main.lua -I). That is the most consequential
    # fallback the script had, because it did not substitute a VALUE -- it
    # substituted a PROGRAM. The operator asked for the menu with the command
    # preview and the per-stage force checkboxes, and got a different interface
    # with a different set of options, after a message that scrolled past. The
    # older mode still exists and can be run directly; it is just not something
    # to be handed silently.
    if ! command -v tui_init >/dev/null; then
        echo "ERROR: the interactive menu library is not loaded." >&2
        echo "       Expected: ${LIBS_DIR}/lua-menu.sh (and luajit on PATH)." >&2
        echo "       -I needs it. Every non-interactive stage still works." >&2
        return 1
    fi

    if ! tui_init; then
        echo "ERROR: the interactive menu failed to initialize." >&2
        echo "       This usually means the terminal is not a TTY -- the menu" >&2
        echo "       cannot render into a pipe or a captured stream." >&2
        return 1
    fi

    # Build the menu
    menu_init
    menu_set_title "Neocities Pipeline" "Use j/k to navigate, space to toggle, Enter to run"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 1: Pipeline Stages (multi - can select multiple)
    # Each checkbox maps to a CLI flag for command preview
    # Issue 10-016: Force regeneration moved here with per-stage options
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "stages" "multi" "Pipeline Stages (toggle stages to run)"

    # Issue 10-016: Global force regenerate option at top of stages
    menu_add_item "stages" "force" "Force regenerate ALL stages" "checkbox" "0" \
        "Force regeneration even if files are fresh" "" "--force"

    menu_add_item "stages" "update_words" "1. Update Words" "checkbox" "1" \
        "Sync input files from words repository" "" "--update-words"
    menu_add_item "stages" "force_update_words" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 1"

    menu_add_item "stages" "extract" "2. Extract" "checkbox" "1" \
        "Extract content from backup archives" "" "--extract"
    menu_add_item "stages" "force_extract" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 2"

    menu_add_item "stages" "parse" "3. Parse" "checkbox" "1" \
        "Parse poems from JSON sources into poems.json" "" "--parse"
    menu_add_item "stages" "force_parse" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 3"

    menu_add_item "stages" "validate" "4. Validate" "checkbox" "1" \
        "Run poem validation" "" "--validate"
    menu_add_item "stages" "force_validate" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 4"

    menu_add_item "stages" "catalog_images" "5. Catalog Images" "checkbox" "1" \
        "Catalog images from input directories" "" "--catalog-images"
    menu_add_item "stages" "force_catalog_images" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 5"

    menu_add_item "stages" "generate_embeddings" "6. Embeddings ⚠️" "checkbox" "0" \
        "Generate embeddings via the inference server" "" "--generate-embeddings"
    menu_add_item "stages" "force_generate_embeddings" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 6"

    menu_add_item "stages" "generate_similarity" "7. Similarity ⚠️" "checkbox" "0" \
        "Build similarity matrix" "" "--generate-similarity"
    menu_add_item "stages" "force_generate_similarity" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 7"

    menu_add_item "stages" "generate_diversity" "8. Diversity ⚠️" "checkbox" "0" \
        "Pre-compute diversity cache" "" "--generate-diversity"
    menu_add_item "stages" "force_generate_diversity" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 8"

    menu_add_item "stages" "generate_html" "9. Generate HTML" "checkbox" "1" \
        "Generate website HTML (chronological + similarity pages)" "" "--generate-html"
    menu_add_item "stages" "force_generate_html" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 9"

    menu_add_item "stages" "generate_wordcloud" "10. Generate Word Cloud" "checkbox" "1" \
        "Generate the word-cloud menu and per-word similarity pages" "" "--generate-wordcloud"
    menu_add_item "stages" "force_generate_wordcloud" "    ↳ Force regenerate" "checkbox" "0" \
        "Force regenerate this stage only" "" "--force-stage 10"

    # Issue 10-016: Dependencies - per-stage force options disabled when global force is checked
    # invert=true means: enable per-stage force when global force is NOT checked
    menu_add_dependency "force_update_words" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_extract" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_parse" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_validate" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_catalog_images" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_generate_embeddings" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_generate_similarity" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_generate_diversity" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_generate_html" "force" "1" "true" \
        "Disabled: global force is active" "orange"
    menu_add_dependency "force_generate_wordcloud" "force" "1" "true" \
        "Disabled: global force is active" "orange"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 2: Configuration Options
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "config" "multi" "Configuration"
    # Issue 10-034: Orchestrator pattern enables parallel HTML with low memory
    # Main thread sends 80KB work slices instead of workers loading 700MB caches
    # Expected memory: ~2.5GB total (vs 14GB+ before fix)
    # Issue 10-065: the descriptions no longer advertise defaults, because there
    # are none. A blank field here is not "use the default" -- it is an absent
    # value, and it surfaces in the same missing-flags report a bare command line
    # produces. The numbers still shown in the field are the menu's pre-filled
    # SUGGESTIONS, which the operator can accept or overwrite; the distinction is
    # that a suggestion is visible on screen before it is used.
    menu_add_item "config" "threads" "Thread Count" "flag" "4:8" \
        "Threads for HTML gen (orchestrator mode)" "" "--threads"
    # Issue 8-022: Pagination options for HTML generation
    menu_add_item "config" "pages" "Pages per Poem" "flag" "1:2" \
        "Pages generated per poem" "" "--pages"
    menu_add_item "config" "poems_per_page" "Poems per Page" "flag" "200:3" \
        "Poems per similar/different page" "" "--poems-per-page"
    menu_add_item "config" "chrono_per_page" "Chrono per Page" "flag" "500:3" \
        "Poems per chronological page" "" "--chrono-per-page"
    # Issue 10-016: Force Regeneration moved to stages section
    menu_add_item "config" "dry_run" "Dry Run" "checkbox" "0" \
        "Show what would be executed without running" "" "--dry-run"
    menu_add_item "config" "verbose" "Verbose Output" "checkbox" "0" \
        "Show detailed progress information" "" "--verbose"
    # Issue 10-065: a checkbox always holds a definite state, so this one always
    # answers --boosts -- unchecked means "no", not "unanswered".
    menu_add_item "config" "include_boosts" "Include Boosts" "checkbox" "0" \
        "Include fediverse boosts/reblogs in extraction and parsing" "" "--boosts yes"
    # The seed stays a typed field because it is a number with no candidate list
    # to pick from -- any non-negative integer is equally valid, which is exactly
    # what makes it reproducible. Left EMPTY: pre-filling a seed would be the
    # auto-generated seed this issue removed, wearing a menu.
    menu_add_item "config" "seed" "Random Seed" "flag" ":12" \
        "Master seed for word-cloud shuffle and image order" "" "--seed"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 2b: Model and server, as PICK-LISTS built from config.lua
    #
    # Issue 10-065: these are lists, not text boxes, and the reason is ergonomic
    # rather than technical. "qwen3-embedding:4b" is an exact string; typing it
    # from memory goes wrong eventually, and the wrong version is only discovered
    # when a stage fails. You cannot mistype something you pick.
    #
    # A "single" section renders as a radio group -- exactly one choice -- and
    # each entry carries the whole "--model NAME" as its CLI flag, so the command
    # preview shows the real, runnable text.
    #
    # The entries are read at menu-build time from config.lua via
    # scripts/list-inference-choices, so adding a server or a model to the config
    # makes it appear here with no edit to this file. That is the point: a
    # hand-maintained copy of the list in run.sh would be a second source of
    # truth, and second sources of truth are what this whole issue is about.
    _choice_servers="$("$DIR/scripts/list-inference-choices" "$DIR" --servers)" || {
        echo "ERROR: could not read the inference server list from config.lua" >&2
        return 1
    }
    _choice_models="$("$DIR/scripts/list-inference-choices" "$DIR" --models)" || {
        echo "ERROR: could not read the embedding model list from config.lua" >&2
        return 1
    }

    # The names are kept in arrays alongside the menu items because the menu
    # library exposes menu_get_value but no menu_get_label -- so the checked item
    # can be identified by index, but its displayed name has to be remembered
    # here. Index i in the array is always item "model_i" / "server_i".
    MODEL_CHOICES=()
    SERVER_CHOICES=()

    menu_add_section "model" "single" "Embedding Model (pick one)"
    while IFS= read -r _m; do
        [ -z "$_m" ] && continue
        # Item ids must be unique and shell-safe, so they are numbered rather
        # than derived from the model name (which contains ':' and '.').
        menu_add_item "model" "model_${#MODEL_CHOICES[@]}" "$_m" "checkbox" "0" \
            "Use the $_m embedding model" "" "--model $_m"
        MODEL_CHOICES+=("$_m")
    done <<< "$_choice_models"

    menu_add_section "server" "single" "Inference Server (pick one)"
    while IFS= read -r _s; do
        [ -z "$_s" ] && continue
        menu_add_item "server" "server_${#SERVER_CHOICES[@]}" "$_s" "checkbox" "0" \
            "Send embedding requests to $_s" "" "--server $_s"
        SERVER_CHOICES+=("$_s")
    done <<< "$_choice_servers"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 3: Word Cloud Configuration
    # Issue 8-043: Configurable word count with "all words" toggle
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "wordcloud" "multi" "Word Cloud Options"
    menu_add_item "wordcloud" "wordcloud_all" "All Words" "checkbox" "0" \
        "Include all words (disables word count limit)" "" "--wordcloud-words all"
    menu_add_item "wordcloud" "wordcloud_words" "Word Count" "flag" "200:3" \
        "Maximum words in word cloud" "" "--wordcloud-words"
    # Issue 8-050d: Poems per word-cloud page
    menu_add_item "wordcloud" "wordcloud_poems" "Poems Per Page" "flag" "50:3" \
        "Poems per word-cloud similarity page" "" "--wordcloud-poems"
    # Dependency: Disable wordcloud_words when wordcloud_all is checked
    # invert=true means: enable wordcloud_words when wordcloud_all is NOT checked (value "1")
    menu_add_dependency "wordcloud_words" "wordcloud_all" "1" "true" \
        "Word count disabled when 'All Words' is checked"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 4: Command Preview (shows the command that will be executed)
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "preview" "multi" "Command Preview"
    menu_add_item "preview" "cmd_preview" "" "text" "" \
        "The command that will be executed (press ~ to copy to clipboard)"

    # Configure command preview - links checkboxes to command string
    menu_set_command_config "./run.sh" "cmd_preview" ""

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 5: Actions
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "actions" "single" "Actions"
    menu_add_item "actions" "run" "Run Selected Stages" "action" "" \
        "Execute the selected pipeline stages" ""

    # Run the menu loop
    while true; do
        if menu_run; then
            # User selected "run" - extract values and execute
            local update_words_val=$(menu_get_value "update_words")
            local extract_val=$(menu_get_value "extract")
            local parse_val=$(menu_get_value "parse")
            local validate_val=$(menu_get_value "validate")
            local catalog_val=$(menu_get_value "catalog_images")
            local embeddings_val=$(menu_get_value "generate_embeddings")
            local similarity_val=$(menu_get_value "generate_similarity")
            local diversity_val=$(menu_get_value "generate_diversity")
            local html_val=$(menu_get_value "generate_html")
            local wordcloud_stage_val=$(menu_get_value "generate_wordcloud")
            local threads_val=$(menu_get_value "threads")
            # Issue 8-022: Get pagination values from TUI
            local pages_val=$(menu_get_value "pages")
            local poems_per_page_val=$(menu_get_value "poems_per_page")
            local chrono_per_page_val=$(menu_get_value "chrono_per_page")
            local force_val=$(menu_get_value "force")
            # Issue 10-016: Get per-stage force values from TUI
            local force_update_words_val=$(menu_get_value "force_update_words")
            local force_extract_val=$(menu_get_value "force_extract")
            local force_parse_val=$(menu_get_value "force_parse")
            local force_validate_val=$(menu_get_value "force_validate")
            local force_catalog_val=$(menu_get_value "force_catalog_images")
            local force_embeddings_val=$(menu_get_value "force_generate_embeddings")
            local force_similarity_val=$(menu_get_value "force_generate_similarity")
            local force_diversity_val=$(menu_get_value "force_generate_diversity")
            local force_html_val=$(menu_get_value "force_generate_html")
            local force_wordcloud_val=$(menu_get_value "force_generate_wordcloud")
            local dry_val=$(menu_get_value "dry_run")
            local verbose_val=$(menu_get_value "verbose")
            # Issue 8-011: Get boost inclusion value from TUI
            local include_boosts_val=$(menu_get_value "include_boosts")
            # Issue 8-043: Get wordcloud values from TUI
            local wordcloud_all_val=$(menu_get_value "wordcloud_all")
            local wordcloud_words_val=$(menu_get_value "wordcloud_words")
            # Issue 8-050d: Get poems per word-cloud page from TUI
            local wordcloud_poems_val=$(menu_get_value "wordcloud_poems")
            # Issue 10-065: the seed, and the two pick-lists.
            local seed_val=$(menu_get_value "seed")

            # Set global flags based on menu selection
            [[ "$update_words_val" == "1" ]] && UPDATE_WORDS=true || UPDATE_WORDS=false
            [[ "$extract_val" == "1" ]] && EXTRACT=true || EXTRACT=false
            [[ "$parse_val" == "1" ]] && PARSE=true || PARSE=false
            [[ "$validate_val" == "1" ]] && VALIDATE=true || VALIDATE=false
            [[ "$catalog_val" == "1" ]] && CATALOG_IMAGES=true || CATALOG_IMAGES=false
            [[ "$embeddings_val" == "1" ]] && GENERATE_EMBEDDINGS=true || GENERATE_EMBEDDINGS=false
            [[ "$similarity_val" == "1" ]] && GENERATE_SIMILARITY=true || GENERATE_SIMILARITY=false
            [[ "$diversity_val" == "1" ]] && GENERATE_DIVERSITY=true || GENERATE_DIVERSITY=false
            [[ "$html_val" == "1" ]] && GENERATE_HTML=true || GENERATE_HTML=false
            [[ "$wordcloud_stage_val" == "1" ]] && GENERATE_WORDCLOUD=true || GENERATE_WORDCLOUD=false

            # Config flags. Issue 10-065: a blank menu field leaves the variable
            # empty, and empty is exactly what the requirement gate reports as
            # missing -- the menu and the command line reach the same gate, so
            # neither route can start a build with a value nobody chose.
            [[ -n "$threads_val" && "$threads_val" != "0" ]] && THREADS="$threads_val"
            # Issue 8-022: Set pagination values from TUI
            [[ -n "$pages_val" && "$pages_val" != "0" ]] && PAGES="$pages_val"
            [[ -n "$poems_per_page_val" && "$poems_per_page_val" != "0" ]] && POEMS_PER_PAGE="$poems_per_page_val"
            [[ -n "$chrono_per_page_val" && "$chrono_per_page_val" != "0" ]] && CHRONO_PER_PAGE="$chrono_per_page_val"
            [[ "$force_val" == "1" ]] && FORCE=true || FORCE=false
            # Issue 10-016: Set per-stage force flags from TUI
            [[ "$force_update_words_val" == "1" ]] && FORCE_STAGE_1=true || FORCE_STAGE_1=false
            [[ "$force_extract_val" == "1" ]] && FORCE_STAGE_2=true || FORCE_STAGE_2=false
            [[ "$force_parse_val" == "1" ]] && FORCE_STAGE_3=true || FORCE_STAGE_3=false
            [[ "$force_validate_val" == "1" ]] && FORCE_STAGE_4=true || FORCE_STAGE_4=false
            [[ "$force_catalog_val" == "1" ]] && FORCE_STAGE_5=true || FORCE_STAGE_5=false
            [[ "$force_embeddings_val" == "1" ]] && FORCE_STAGE_6=true || FORCE_STAGE_6=false
            [[ "$force_similarity_val" == "1" ]] && FORCE_STAGE_7=true || FORCE_STAGE_7=false
            [[ "$force_diversity_val" == "1" ]] && FORCE_STAGE_8=true || FORCE_STAGE_8=false
            [[ "$force_html_val" == "1" ]] && FORCE_STAGE_9=true || FORCE_STAGE_9=false
            [[ "$force_wordcloud_val" == "1" ]] && FORCE_STAGE_10=true || FORCE_STAGE_10=false
            [[ "$dry_val" == "1" ]] && DRY_RUN=true || DRY_RUN=false
            [[ "$verbose_val" == "1" ]] && VERBOSE=true || VERBOSE=false
            # Issue 8-011/10-065: the boost checkbox now answers --boosts with a
            # definite yes or no. A checkbox cannot be "unanswered", which is why
            # this is the one required value the menu can always supply.
            if [[ "$include_boosts_val" == "1" ]]; then
                BOOSTS="yes"
            else
                BOOSTS="no"
            fi
            # Issue 8-043: Set the word count from the TUI. The "All Words" checkbox
            # wins -- it sets the count to the literal "all" (and the dependency has
            # already disabled the now-irrelevant Word Count field). Otherwise the
            # typed count is used. One value, WORDCLOUD_WORDS, feeds --wordcloud-words.
            if [[ "$wordcloud_all_val" == "1" ]]; then
                WORDCLOUD_WORDS="all"
            elif [[ -n "$wordcloud_words_val" && "$wordcloud_words_val" != "0" ]]; then
                WORDCLOUD_WORDS="$wordcloud_words_val"
            fi
            # Issue 8-050d: Set poems per word-cloud page from TUI
            [[ -n "$wordcloud_poems_val" && "$wordcloud_poems_val" != "0" ]] && WORDCLOUD_POEMS="$wordcloud_poems_val"

            # Issue 10-065: the seed. No "!= 0" guard here, unlike the fields
            # above: zero is a PERFECTLY VALID seed, and treating it as "unset"
            # would silently reject a reproducible build the operator asked for.
            # (The guard exists on the others because the menu uses "0" to mean
            # an untouched numeric field, and zero threads or zero pages are
            # meaningless anyway.)
            [[ -n "$seed_val" ]] && RANDOM_SEED="$seed_val"

            # The model and server pick-lists. Each entry is a checkbox in a
            # "single" section, so at most one is checked; walk them and take the
            # one that is, reading its name out of the array built alongside the
            # menu items (index i <-> item "model_i").
            #
            # Nothing is assigned when nothing is checked: the variable stays
            # empty and the requirement gate reports it as missing, which is the
            # same outcome as omitting the flag on the command line. Both doors,
            # one gate.
            local _i _val
            _i=0
            while [ "$_i" -lt "${#MODEL_CHOICES[@]}" ]; do
                _val=$(menu_get_value "model_$_i")
                [[ "$_val" == "1" ]] && MODEL_NAME="${MODEL_CHOICES[$_i]}"
                _i=$((_i + 1))
            done
            _i=0
            while [ "$_i" -lt "${#SERVER_CHOICES[@]}" ]; do
                _val=$(menu_get_value "server_$_i")
                [[ "$_val" == "1" ]] && INFERENCE_SERVER="${SERVER_CHOICES[$_i]}"
                _i=$((_i + 1))
            done

            # Check if at least one stage is selected
            if ! $UPDATE_WORDS && ! $EXTRACT && ! $PARSE && ! $VALIDATE && \
               ! $CATALOG_IMAGES && ! $GENERATE_EMBEDDINGS && ! $GENERATE_SIMILARITY && \
               ! $GENERATE_DIVERSITY && ! $GENERATE_HTML && ! $GENERATE_WORDCLOUD; then
                echo ""
                echo "No stages selected. Please select at least one stage to run."
                echo "Press Enter to continue..."
                read -r
                continue
            fi

            # Exit menu and run the pipeline
            menu_cleanup
            return 0
        else
            # User quit
            menu_cleanup
            echo "Goodbye!"
            exit 0
        fi
    done
}
# }}}

# {{{ Main execution

# Handle interactive mode
EXECUTED_COMMAND=""  # Store command for post-run display
if $INTERACTIVE; then
    log_info "🎛️ Launching interactive mode with command preview..."
    interactive_mode_tui || {
        echo "Error: interactive mode could not start." >&2
        exit 1
    }
    # Save the command preview for display after execution
    EXECUTED_COMMAND=$(menu_get_value "cmd_preview")
    # After TUI, fall through to execute selected stages
fi

# {{{ The requirement gate (Issue 10-065)
# Placed HERE, and the position is the design. Two things must already have
# happened and one must not have:
#
#   The stage selection must be final -- requirements follow the selected
#   stages, and the menu above is the second way stages get selected.
#   The menu's values must be in, for the same reason: menu and command line
#   are two doors into one gate, and a build must not be startable through
#   either one with a value nobody chose.
#   Nothing may have RESOLVED a value yet. The model resolution below used to
#   sit hundreds of lines above this point, where it read config.lua whenever
#   --model was absent. A resolver that runs before the gate makes the gate
#   decorative: it would find the value present, because the resolver had just
#   invented it.
collect_missing_values
if [ "${#MISSING_VALUES[@]}" -gt 0 ] && $INTERACTIVE; then
    # Every required value has somewhere to come from in the menu, so an absence
    # here means a field was left blank or a list left unpicked -- not that the
    # menu was incapable of expressing it. Point at the section rather than at
    # the command line.
    echo "" >&2
    echo "Note: the menu can supply all of these -- the Configuration section" >&2
    echo "      for the numbers and the seed, and the Embedding Model and" >&2
    echo "      Inference Server pick-lists for the names." >&2
fi
report_missing_values
validate_supplied_values
# }}}

# {{{ Record this run's choices where the child programs will find them
# Why this exists: run.sh launches a fresh luajit process per stage, and argv
# reaches only the stages we remember to thread it through. Before the notepad, a
# --model override silently reverted to config.lua's default in the HTML,
# word-cloud and word-page stages (they resolve the model via get_selected_model()
# / embeddings_dir() with no argument). The fix is a shared notepad in RAM: this
# run's choices are stamped onto tmp/shared-memory/run-overrides.lua once, here,
# and the resolver reads them. It is rewritten every run, so a previous run's
# choice can never leak in -- the staleness trap a file has but an env var does
# not.
#
# Issue 10-065: the server is recorded alongside the model, and BOTH are recorded
# only when this run actually has them. Which stages require a model is decided by
# the requirements table above, and stages 1-5 do not -- so a --validate run
# reaches this point with MODEL_NAME empty, legitimately. The notepad writer
# already skips empty values (an absent key means "no override"), so passing them
# through unguarded is safe here; the cache-directory block below is where an
# empty model was NOT safe. See its comment.
"$DIR/scripts/write-run-overrides" "$DIR" \
    --model "$MODEL_NAME" \
    --server "$INFERENCE_SERVER" || {
    echo "Error: failed to record run overrides (scripts/write-run-overrides)" >&2
    exit 1
}

# Create this model's cache directories ONCE here, instead of making each stage
# remember to mkdir its own output dir before its first write. The paths are
# inferred from the model name by scripts/cache-dir (the single place that maps a
# model -> its directories): the movable (RAM) dir, its similarities/ subdir, and
# the reboot-surviving on-disk dir (--disk). A brand-new model otherwise has no
# assets/embeddings/<model>/ folder, which once let a 40-minute diversity run
# finish and then fail at its final write. Adding a new model now needs no manual
# mkdir -- selecting it is enough.
#
# Issue 10-065: guarded on having a model at all. This block used to run on EVERY
# invocation, and `scripts/cache-dir --model ""` resolves to the embeddings ROOT
# rather than to a model's subdirectory -- so `./run.sh --validate`, a stage that
# requires no model, created a stray `cache/embeddings/similarities/` one level
# above where any similarity file belongs. Found by noticing that exact directory
# on this machine and matching its timestamp to a --validate --dry-run.
if [ -n "$MODEL_NAME" ]; then
    _ram_dir="$(luajit "$DIR/scripts/cache-dir" "$DIR" --model "$MODEL_NAME")"
    _disk_dir="$(luajit "$DIR/scripts/cache-dir" "$DIR" --model "$MODEL_NAME" --disk)"
    if [ -z "$_ram_dir" ] || [ -z "$_disk_dir" ]; then
        echo "Error: could not resolve cache directories for model $MODEL_NAME" >&2
        exit 1
    fi
    # The dry-run guard is the same rule the stage functions follow: --dry-run
    # must not change anything. This mkdir used to run regardless, so a --dry-run
    # with a mistyped --model left a real, empty cache directory behind -- named
    # after a model that does not exist, sitting beside the real ones, and
    # indistinguishable from a model whose embeddings simply have not been
    # generated yet.
    if $DRY_RUN; then
        log_dry_run "mkdir -p $_ram_dir/similarities $_disk_dir (cache dirs for $MODEL_NAME)"
    else
        mkdir -p "$_ram_dir/similarities" "$_disk_dir" || {
            echo "Error: could not create cache directories for model $MODEL_NAME" >&2
            exit 1
        }
    fi
fi
# }}}

# {{{ The build's master seed
# One integer governs every randomization site this run (the word-cloud shuffle
# and image-order randomization).
#
# Resolution: --seed if given, otherwise a fresh random one. An unseeded build is
# NOT refused, because refusing would not make anyone's choice more deliberate --
# it would just make them type a number to get past a prompt. What makes an
# unseeded build reproducible is that the seed is RECORDED, which is Issue
# 10-058's design and is what happens below: it is logged, written into
# generation-metadata.json, and stamped into the word-cloud page itself, so any
# archived cloud can be re-created from the file.
#
# Entropy: the epoch second alone would give two runs in the same second the same
# seed, so the process id is mixed in. Folded to a 31-bit non-negative integer so
# it round-trips unchanged through a command line, JSON, and math.randomseed.
if [ -z "$RANDOM_SEED" ]; then
    RANDOM_SEED=$(( ($(date +%s) * 100000 + $$) % 2147483647 ))
    RANDOM_SEED_SOURCE="randomized (no --seed given)"
else
    RANDOM_SEED_SOURCE="--seed"
fi

# The argument every randomizing subprocess receives. Equals-form on purpose: the
# bare number can never be mistaken for a positional DIR by a child's arg parser.
RANDOM_SEED_ARG="--seed=$RANDOM_SEED"
log_info "🎲 Random seed: $RANDOM_SEED ($RANDOM_SEED_SOURCE)"
# }}}

# {{{ Record what produced this build
# Written when this run required at least one value -- which is the same as
# saying it did something whose parameters are worth recording. Stages 1-4
# require nothing, so a --validate run writes no record and, importantly, does
# not OVERWRITE the existing one: that file still truthfully describes the build
# whose pages are sitting in output/ right now, which validating did not touch.
# Erasing it would be the fallback pattern in reverse -- replacing a value
# somebody supplied with one nobody did.
#
# Known limitation, worth stating rather than hiding: the file is replaced, not
# merged. output/ can hold pages from several runs (stage 9 today, stage 10 last
# week), and a replaced record then describes only the most recent. Merging would
# be more truthful and needs a JSON reader this shell script does not have.
_run_required_something=false
for _row in "${REQUIRED_VALUES[@]}"; do
    IFS=';' read -r _var _usage _reason _consumers _key <<< "$_row"
    IFS=',' read -r -a _entries <<< "$_consumers"
    for _entry in "${_entries[@]}"; do
        _sv="${_entry%%:*}"
        [ "${!_sv}" = "true" ] && _run_required_something=true
    done
done
# The seed left the requirements table, so the stages that consume it have to be
# named here or a run of stage 5 alone (image-order randomization, no other
# required values) would randomize the gallery and record nothing about it.
$CATALOG_IMAGES && _run_required_something=true
$GENERATE_WORDCLOUD && _run_required_something=true

if $_run_required_something; then
    if $DRY_RUN; then
        log_dry_run "write $OUTPUT_DIR/generation-metadata.json (this run's values)"
    else
        write_generation_metadata
    fi
fi
# }}}

# Show what will be executed (in non-interactive or after TUI selection)
if $DRY_RUN || $VERBOSE; then
    echo "Pipeline stages to execute:"
    # Issue 10-051 / alignment: render the plan as a TABLE -- stage names in one
    # left-aligned column, the measured average time right-aligned in the next --
    # so durations line up and the eye can scan them. Measured wall-clock (avg of
    # recent runs) appears once a stage has run here before; until then a coarse
    # magnitude word (short/medium/long) stands in, since a word can't go stale
    # the way a hard number can. The ⚠ marks the heavy stages.
    #
    # Each row is "enabled|number|name|warned|timing-key|magnitude". The timing
    # key can differ from the display name (word-cloud history is stored under
    # "wordcloud" but shown as "generate-wordcloud").
    _plan_rows=(
        "$UPDATE_WORDS|1|update-words|0|update-words|short"
        "$EXTRACT|2|extract|0|extract|short"
        "$PARSE|3|parse|0|parse|short"
        "$VALIDATE|4|validate|0|validate|short"
        "$CATALOG_IMAGES|5|catalog-images|0|catalog-images|short"
        "$GENERATE_EMBEDDINGS|6|generate-embeddings|1|generate-embeddings|long"
        "$GENERATE_SIMILARITY|7|generate-similarity|1|generate-similarity|medium"
        "$GENERATE_DIVERSITY|8|generate-diversity|1|generate-diversity|medium"
        "$GENERATE_HTML|9|generate-html|0|generate-html|medium"
        "$GENERATE_WORDCLOUD|10|generate-wordcloud|0|wordcloud|short"
    )
    # Issue 10-065: the timing library is required to load (see "Setup
    # directories"), so this asks whether it exports the reader function, not
    # whether it is present. If it loaded but is missing the function, that is a
    # broken library rather than an absent one, and saying so beats printing a
    # plan with silently degraded estimates.
    if ! command -v stage_timing_mean >/dev/null; then
        echo "Error: scripts/stage-timing.sh loaded but exports no stage_timing_mean." >&2
        exit 1
    fi

    # Pass 1: collect enabled rows + each one's time string and tail, and track
    # the widest label and widest time. The ⚠ glyph is counted as ONE display
    # column (not its byte length) so the multibyte char does not skew alignment.
    _p_num=(); _p_label=(); _p_lvis=(); _p_time=(); _p_tail=()
    _labelw=0; _timew=0
    for _row in "${_plan_rows[@]}"; do
        IFS='|' read -r _en _num _name _warn _key _mag <<< "$_row"
        [ "$_en" = "true" ] || continue
        _lbl="$_name"; _lvis=${#_name}
        if [ "$_warn" = "1" ]; then _lbl="$_name $(symbol_warning "⚠")"; _lvis=$(( ${#_name} + 2 )); fi
        _time=""; _tail="$_mag"
        # An empty mean is legitimate here and is NOT a fallback: it means this
        # stage has no recorded history yet, so the coarse magnitude word stands
        # in until it does. The distinction from a fallback is that the estimate
        # is labelled -- "(medium)" versus "(avg 4m 12s, last 3 runs)" -- so the
        # reader can always tell a measurement from a guess.
        _mean="$(stage_timing_mean "$_key")"
        if [ -n "$_mean" ]; then
            _cnt="$(stage_timing_count "$_key")"
            _pl="s"; [ "$_cnt" = "1" ] && _pl=""
            _time="$(stage_timing_format_seconds "$_mean")"
            _tail="last ${_cnt} run${_pl}"
        fi
        _p_num+=("$_num"); _p_label+=("$_lbl"); _p_lvis+=("$_lvis")
        _p_time+=("$_time"); _p_tail+=("$_tail")
        [ "$_lvis" -gt "$_labelw" ] && _labelw=$_lvis
        [ "${#_time}" -gt "$_timew" ] && _timew=${#_time}
    done

    # Pass 2: print aligned. Number in a 3-wide field ("1." / "10."), label padded
    # to _labelw, time right-aligned to _timew inside "(avg <time>, <tail>)".
    _i=0
    while [ "$_i" -lt "${#_p_num[@]}" ]; do
        _pad=$(( _labelw - ${_p_lvis[$_i]} ))
        _sp=""; [ "$_pad" -gt 0 ] && _sp="$(printf '%*s' "$_pad" '')"
        if [ -n "${_p_time[$_i]}" ]; then
            printf "  %-3s %s%s (avg %*s, %s)\n" \
                "${_p_num[$_i]}." "${_p_label[$_i]}" "$_sp" \
                "$_timew" "${_p_time[$_i]}" "${_p_tail[$_i]}"
        else
            printf "  %-3s %s%s (%s)\n" \
                "${_p_num[$_i]}." "${_p_label[$_i]}" "$_sp" "${_p_tail[$_i]}"
        fi
        _i=$(( _i + 1 ))
    done
    echo ""
fi

# {{{ Issue 10-017: Validate Inference server connectivity before embedding stages
if $GENERATE_EMBEDDINGS && ! $DRY_RUN; then
    log_info "Validating Inference server connectivity..."
    VALIDATION_RESULT=$(luajit -e "
        package.path = '$DIR/libs/?.lua;' .. package.path
        local inference = require('inference-server-config')
        -- Issue 10-065: unconditional. --server is required by this stage, so
        -- there is no empty-means-let-config-decide case -- which matters here
        -- more than anywhere, because this block decides which endpoint to
        -- health-check and, failing that, which one to START.
        inference.set_selected_server('$INFERENCE_SERVER')
        local server = inference.get_selected_server()
        local ok, msg = inference.validate_server(server)
        if ok then
            print('OK:' .. server.name .. ':' .. inference.build_host_url(server))
        else
            print('FAIL:' .. server.name .. ':' .. msg)
        end
    " 2>&1)

    if [[ "$VALIDATION_RESULT" == OK:* ]]; then
        SERVER_NAME=$(echo "$VALIDATION_RESULT" | cut -d: -f2)
        SERVER_URL=$(echo "$VALIDATION_RESULT" | cut -d: -f3-)
        log_info "   ✓ Inference server '$SERVER_NAME' is reachable at $SERVER_URL"
    else
        # Server unreachable. Try to start it ourselves (and remember we
        # did, so the EXIT trap shuts it down again). If start succeeds,
        # re-validate to confirm /health is responsive before proceeding.
        SERVER_NAME=$(echo "$VALIDATION_RESULT" | cut -d: -f2)
        ERROR_MSG=$(echo "$VALIDATION_RESULT" | cut -d: -f3-)
        log_info "   ✗ Inference server '$SERVER_NAME' not reachable: $ERROR_MSG"
        log_info "   Attempting to start it via scripts/start-llamacpp-server.sh..."

        # Issue 10-065: the server name is always passed. It used to be appended
        # only when non-empty, so an omitted --server meant this script started
        # whichever server config.lua named -- and then the EXIT trap shut down
        # a server the operator had never mentioned.
        START_ARGS=("$DIR" "--server=$INFERENCE_SERVER")
        if "$DIR/scripts/start-llamacpp-server.sh" "${START_ARGS[@]}"; then
            WE_STARTED_INFERENCE_SERVER=true

            # Re-validate to confirm the freshly-started server is responsive.
            VALIDATION_RESULT=$(luajit -e "
                package.path = '$DIR/libs/?.lua;' .. package.path
                local inference = require('inference-server-config')
                -- Issue 10-065: unconditional, matching the first validation
                -- block above. --server is required by this stage, so the
                -- empty case cannot arise.
                inference.set_selected_server('$INFERENCE_SERVER')
                local server = inference.get_selected_server()
                local ok, msg = inference.validate_server(server)
                if ok then
                    print('OK:' .. server.name .. ':' .. inference.build_host_url(server))
                else
                    print('FAIL:' .. server.name .. ':' .. msg)
                end
            " 2>&1)

            if [[ "$VALIDATION_RESULT" == OK:* ]]; then
                SERVER_NAME=$(echo "$VALIDATION_RESULT" | cut -d: -f2)
                SERVER_URL=$(echo "$VALIDATION_RESULT" | cut -d: -f3-)
                log_info "   ✓ Inference server '$SERVER_NAME' started at $SERVER_URL"
                log_info "   (will be shut down again when this run completes)"
            else
                ERROR_MSG=$(echo "$VALIDATION_RESULT" | cut -d: -f3-)
                echo -e "${RED}❌ ERROR: Started the inference server but it is still not reachable${NC}" >&2
                echo -e "${RED}   $ERROR_MSG${NC}" >&2
                # Issue 10-065: the log directory is stated rather than guessed
                # at with a ":-" default. --debug moves these logs to durable
                # disk; without it they are in the RAM-backed tmp/ and a reboot
                # takes them, which is precisely what an operator chasing a
                # server that will not start needs to be told.
                if [ -n "$NEOCITIES_LOG_DIR" ]; then
                    echo -e "${YELLOW}💡 Check $NEOCITIES_LOG_DIR/llamacpp-server.log for the server's own diagnostics${NC}" >&2
                else
                    echo -e "${YELLOW}💡 Check $DIR/tmp/llamacpp-server.log for the server's own diagnostics${NC}" >&2
                    echo -e "${YELLOW}   (that is RAM-backed and a reboot wipes it; re-run with --debug to keep it)${NC}" >&2
                fi
                exit 1
            fi
        else
            echo -e "${RED}❌ ERROR: Failed to start the inference server${NC}" >&2
            echo -e "${YELLOW}💡 Run ./scripts/start-llamacpp-server.sh manually for verbose output${NC}" >&2
            echo -e "${YELLOW}💡 Use --list-servers to see available servers${NC}" >&2
            echo -e "${YELLOW}💡 Use --server=NAME to select a different server${NC}" >&2
            exit 1
        fi
    fi
fi
# }}}

# Execute stages in pipeline order (regardless of argument order)
# Issue 10-051: timed_stage <name> wraps each stage so its wall-clock is recorded
# to .stage-timings on success (skipped stages and failures record nothing). The
# names here are the keys the pre-flight list reads back for its estimates.
$UPDATE_WORDS && timed_stage update-words run_update_words
$EXTRACT && timed_stage extract run_extract
# Issue 10-053: strip excluded content from input/ right after sync/extraction,
# before anything catalogs or embeds it. Tied to extraction (which follows sync).
$EXTRACT && timed_stage strip-excluded run_strip_excluded
$PARSE && timed_stage parse run_parse
$VALIDATE && timed_stage validate run_validate
$CATALOG_IMAGES && timed_stage catalog-images run_catalog_images
$GENERATE_EMBEDDINGS && timed_stage generate-embeddings run_generate_embeddings
# Semantic colors are part of embedding generation (Stage 6.5)
# Only regenerate when embeddings are generated - HTML should use existing poem_colors.json
$GENERATE_EMBEDDINGS && timed_stage generate-semantic-colors run_generate_semantic_colors
# Word embeddings run AFTER colors so the word-color step finds color_embeddings.json
$GENERATE_EMBEDDINGS && timed_stage generate-word-embeddings run_generate_word_embeddings
# Issue 9-013: fold image pseudo-embeddings into the set BEFORE the similarity
# matrix is built, so images rank alongside poems. Idempotent + cheap.
$GENERATE_SIMILARITY && timed_stage augment-images run_augment_images
$GENERATE_SIMILARITY && timed_stage generate-similarity run_generate_similarity
$GENERATE_DIVERSITY && timed_stage generate-diversity run_generate_diversity
$GENERATE_HTML && timed_stage generate-html run_generate_html
$GENERATE_WORDCLOUD && timed_stage wordcloud run_generate_wordcloud

if ! $QUIET; then
    echo ""
    echo -e "$(symbol_success "✅") Pipeline completed successfully"

    # Print the executed command for easy re-running (copy-paste friendly)
    if [[ -n "$EXECUTED_COMMAND" ]]; then
        echo ""
        echo -e "$(symbol_info "📋") Command executed:"
        echo "  $EXECUTED_COMMAND"
    fi
fi
# }}}
