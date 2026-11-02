#!/bin/bash
# test-ticket-hook.sh - proves the ticket post-commit hook previews and
# writes nothing unless told to, installs only where asked, and never
# replaces someone else's hook; and that the `ticket` command hands over to
# the right tools.
#
# In general terms: a scratch monorepo in a RAM folder gets the hook
# installed by install-ticket-hook.sh, then real commits are made in it, and
# their output and the files they leave are checked. The configuration and
# ledger used are scratch files too. Exercises issue 022.
#
# Usage: test-ticket-hook.sh [--dir MONOREPO]

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
[ "${1:-}" = "--dir" ] && [ -n "${2:-}" ] && DIR="$2"
MONOREPO="$DIR"

SCRIPTS="$MONOREPO/delta-version/scripts"
HOOK="$SCRIPTS/ticket-hook.sh"
INSTALL="$SCRIPTS/install-ticket-hook.sh"
TICKET="$SCRIPTS/ticket"
SCRATCH="$MONOREPO/delta-version/tmp/shared-memory/ticket-hook-test"

PASS=0
FAIL=0

# -- {{{ check
function check() {
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

# -- {{{ same / has_line / lacks_line / is_file / no_file
function same() { if [ "$1" = "$2" ]; then echo yes; else echo no; fi; }
function has_line() { if grep -qF -- "$2" <<< "$1"; then echo yes; else echo no; fi; }
function lacks_line() { if grep -qF -- "$2" <<< "$1"; then echo no; else echo yes; fi; }
function is_file() { if [ -f "$1" ]; then echo yes; else echo no; fi; }
function no_file() { if [ -e "$1" ]; then echo no; else echo yes; fi; }
# }}}

# -- {{{ commit
function commit() {
    # Commits everything in the fixture with the scratch configuration; sets
    # OUT (the commit's output, the hook's included) and CODE.
    git -C "$FIXTURE" add -A
    OUT=$(TICKET_HOOK_CONFIG="$CONF" git -C "$FIXTURE" -c user.name=t \
          -c user.email=t@example.invalid commit -q -m "$1" 2>&1)
    CODE=$?
}
# }}}

# -- {{{ build_fixture
function build_fixture() {
    source "$MONOREPO/scripts/libs/ensure-ram-tiers"
    ensure_ram_tiers "$MONOREPO/delta-version" || exit 1
    rm -rf "$SCRATCH"
    mkdir -p "$SCRATCH"
    SCRATCH=$(realpath "$SCRATCH")
    FIXTURE="$SCRATCH/monorepo"
    CONF="$SCRATCH/ticket-hooks.conf"
    LEDGER="$SCRATCH/ledger.tsv"
    TEMPLATES="$FIXTURE/delta-version/templates/tickets"

    mkdir -p "$FIXTURE/alpha/src" "$FIXTURE/alpha/issues" "$TEMPLATES"
    echo "return 1" > "$FIXTURE/alpha/src/a.lua"
    echo "# Issue 101: first" > "$FIXTURE/alpha/issues/101-first.md"
    echo "# delta" > "$FIXTURE/delta-version/README.md"
    git -C "$FIXTURE" init -q
    git -C "$FIXTURE" add -A
    git -C "$FIXTURE" -c user.name=t -c user.email=t@example.invalid commit -q -m "fixture"

    cat > "$CONF" <<EOF
write = off
ledger = $LEDGER
alpha-check.md = --phase=current --projects=alpha
alpha-written.md = --phase=current --projects=alpha --slug=written
EOF
}
# }}}

# -- {{{ test_config
function test_config() {
    local out bad="$SCRATCH/bad.conf"
    out=$(bash "$HOOK" --check --config "$MONOREPO/delta-version/config/ticket-hooks.conf" 2>&1)
    check "the shipped configuration is sound" "$(same "$?" 0)"
    check "the shipped configuration has writing off" "$(has_line "$out" "write = off")"

    out=$(bash "$HOOK" --check --config "$CONF" 2>&1)
    check "the test configuration is sound, with 2 templates" \
        "$(has_line "$out" "2 template(s) with targets")"

    cat > "$bad" <<'EOF'
write = maybe
colour = blue
a.md = --phase=1 --projects=alpha --write
b.md = --phase=1 --dir=/elsewhere
sub/c.md = --phase=1
d.md = --projects=alpha
e.md = --phase=1 --projects=$(touch-me)
EOF
    out=$(bash "$HOOK" --check --config "$bad" 2>&1)
    check "a bad configuration: --check exits 1" "$(same "$?" 1)"
    check "write takes only on or off" "$(has_line "$out" 'write is on or off, not "maybe"')"
    check "an unknown setting is named" "$(has_line "$out" "unknown setting colour")"
    check "a line cannot turn on --write" "$(has_line "$out" "--write is not an option the hook passes on")"
    check "a line cannot move --dir" "$(has_line "$out" "--dir=/elsewhere is not an option")"
    check "a template is named, not given as a path" "$(has_line "$out" "name the template file only")"
    check "a line must give --phase" "$(has_line "$out" "give --phase=")"
    check "a value with shell characters is refused" "$(has_line "$out" 'line 7: --projects=$(touch-me) is not')"
    check "write stays off after a bad write line" "$(has_line "$out" "write = off")"
}
# }}}

# -- {{{ test_install
function test_install() {
    local out hook="$FIXTURE/.git/hooks/post-commit"
    out=$(bash "$INSTALL" --repo "$FIXTURE" --status)
    check "status before installing: not installed" "$(has_line "$out" "not installed")"
    bash "$INSTALL" --repo "$SCRATCH" > /dev/null 2>&1
    check "a folder that is not a repository: refused (2)" "$(same "$?" 2)"

    out=$(bash "$INSTALL" --repo "$FIXTURE")
    check "install writes the post-commit hook" "$(is_file "$hook")"
    check "... executable" "$(if [ -x "$hook" ]; then echo yes; else echo no; fi)"
    check "... calling ticket-hook.sh, never stopping the commit" \
        "$(has_line "$(cat "$hook")" "ticket-hook.sh || true")"
    check "install says it is preview only" "$(has_line "$out" "preview only")"
    out=$(bash "$INSTALL" --repo "$FIXTURE")
    check "installing twice changes nothing" "$(has_line "$out" "already installed")"
    out=$(bash "$INSTALL" --repo "$FIXTURE" --uninstall)
    check "uninstall removes it" "$(no_file "$hook")"

    printf '#!/bin/sh\necho mine\n' > "$hook"
    chmod +x "$hook"
    out=$(bash "$INSTALL" --repo "$FIXTURE" 2>&1)
    check "someone else's hook: install refuses (1)" "$(same "$?" 1)"
    check "... leaves it as it was" "$(same "$(cat "$hook")" "$(printf '#!/bin/sh\necho mine')")"
    check "... and says how to call the ticket hook from it" "$(has_line "$out" "ticket-hook.sh || true")"
    bash "$INSTALL" --repo "$FIXTURE" --uninstall > /dev/null 2>&1
    check "someone else's hook: uninstall refuses (1)" "$(same "$?" 1)"
    check "... and leaves it" "$(is_file "$hook")"
    rm -f "$hook"
    bash "$INSTALL" --repo "$FIXTURE" > /dev/null
}
# }}}

# -- {{{ test_commits
function test_commits() {
    local command
    echo "return 2" > "$FIXTURE/alpha/src/b.lua"
    commit "no template"
    check "a commit with no template change: the hook says nothing" "$(same "$OUT" "")"

    printf '# Alpha Check\n\nFor ][project_name[]\n' > "$TEMPLATES/alpha-check.md"
    commit "add a template"
    check "the commit goes through" "$(same "$CODE" 0)"
    check "the hook previews the template's filing" \
        "$(has_line "$OUT" "would write issues/102-alpha-check.md (phase 1)")"
    check "... and prints the command that would file it" "$(has_line "$OUT" "to file it, run:")"
    check "with write = off nothing is written" "$(no_file "$FIXTURE/alpha/issues/102-alpha-check.md")"
    check "... and no ledger is made" "$(no_file "$LEDGER")"

    command=$(grep -A1 "to file it, run:" <<< "$OUT" | tail -1)
    check "the printed command ends in --write" "$(same "${command##* }" "--write")"
    eval "$command" > /dev/null 2>&1
    check "running the printed command files the ticket" \
        "$(is_file "$FIXTURE/alpha/issues/102-alpha-check.md")"

    printf '# Unlisted\n' > "$TEMPLATES/unlisted.md"
    commit "a template with no targets"
    check "a template with no targets is named and left alone" \
        "$(has_line "$OUT" "unlisted.md changed; no targets for it")"

    sed -i 's/^write = off$/write = on/' "$CONF"
    printf '# Alpha Written\n\nFor ][project_name[]\n' > "$TEMPLATES/alpha-written.md"
    commit "write on"
    check "with write = on the hook files the ticket" \
        "$(is_file "$FIXTURE/alpha/issues/103-written.md")"
    check "... into the configured ledger" "$(has_line "$(cat "$LEDGER" 2>/dev/null)" "alpha-written.md")"
    sed -i 's/^write = on$/write = off/' "$CONF"

    echo "colour = blue" >> "$CONF"
    printf '\nchanged\n' >> "$TEMPLATES/alpha-check.md"
    commit "a bad configuration"
    check "a bad configuration never stops a commit" "$(same "$CODE" 0)"
    check "... and is named in the commit's output" "$(has_line "$OUT" "unknown setting colour")"
    sed -i '/^colour = blue$/d' "$CONF"

    git -C "$FIXTURE" rm -q "$TEMPLATES/unlisted.md"
    commit "remove a template"
    check "removing a template previews nothing" "$(same "$OUT" "")"
}
# }}}

# -- {{{ test_ticket_command
function test_ticket_command() {
    local out
    out=$(bash "$TICKET" --help)
    check "ticket --help lists its commands" "$(has_line "$out" "ticket hook install")"
    bash "$TICKET" frobnicate > /dev/null 2>&1
    check "ticket with an unknown command: 2" "$(same "$?" 2)"
    out=$(DIR="$FIXTURE" bash "$TICKET" file "$TEMPLATES/alpha-check.md" --phase=3 --projects=alpha --again \
          --ledger="$LEDGER" 2>&1)
    check "ticket file runs distribute-ticket on DIR" "$(has_line "$out" "would write issues/301-alpha-check.md")"
    out=$(DIR="$FIXTURE" bash "$TICKET" hook status)
    check "ticket hook status reports the install" "$(has_line "$out" "installed at")"
    out=$(TICKET_HOOK_CONFIG="$CONF" bash "$TICKET" hook check)
    check "ticket hook check reads the configuration" "$(has_line "$out" "write = off")"
    out=$(bash "$TICKET" history --ledger "$LEDGER")
    check "ticket history reads the ledger" "$(has_line "$out" "alpha-written.md")"
    out=$(bash "$TICKET" check "$TEMPLATES/alpha-check.md" 2>&1)
    check "ticket check checks a template's keywords" "$(same "$?" 0)"
    DIR="$FIXTURE" bash "$TICKET" hook uninstall > /dev/null
    check "ticket hook uninstall removes it" "$(no_file "$FIXTURE/.git/hooks/post-commit")"
}
# }}}

# -- {{{ main
function main() {
    build_fixture
    echo "ticket hook against a scratch monorepo in $SCRATCH"
    test_config
    test_install
    test_commits
    test_ticket_command
    [ -n "$KEEP" ] || rm -rf "$SCRATCH"
    echo
    echo "$PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}
# }}}

main
