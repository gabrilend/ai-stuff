#!/usr/bin/env bash
#
# test-graft-project-histories.sh - checks the history-graft tool on a small
# made-up repository before it is ever pointed at the real one.
#
# In plain terms: it builds a toy "monorepo" whose first commit gathered two
# toy projects that each had a few commits of their own, runs the graft tool's
# prepare step on it, checks every promise the tool makes (same files, same
# authors and dates, joined histories, rewritten quotes), then runs the swap
# step through a pretend terminal and checks the toy trunk really moved. The
# quote-rewriting library is also tested alone, on hand-made text.
#
# Usage: test-graft-project-histories.sh [scratch-dir]
# Everything happens under the scratch directory (default in /tmp); nothing
# outside it is touched.

set -euo pipefail

# {{{ configuration
DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
T="${1:-/tmp/test-graft-project-histories}"
TOOL="${DIR}/graft-project-histories"
LIB="${DIR}/libs/commit-id-quotes.lua"
PASS=0
FAIL=0
# }}}

# {{{ check
check() {
   local name="$1" ok="$2"
   if [ "${ok}" = yes ]; then PASS=$((PASS + 1)); printf '  ok    %s\n' "${name}"
   else FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "${name}"; fi
}
# }}}

# {{{ yn
yn() { if "$@"; then echo yes; else echo no; fi; }
# fails: succeeds when the command fails, so a refusal can be checked with yn.
fails() { ! "$@"; }
# quiet: runs a command with no input and no output, keeping only its status.
quiet() { "$@" < /dev/null > /dev/null 2>&1; }
# }}}

# {{{ unit_tests
unit_tests() {
   echo "quote rewriting, alone"
   luajit - "${LIB}" <<'LUA'
      local q = dofile(arg[1])
      local pass, fail = 0, 0
      local function check(name, ok)
         if ok then pass = pass + 1; print("  ok    " .. name)
         else fail = fail + 1; print("  FAIL  " .. name) end
      end
      local A = "aaaaaaa1" .. ("0"):rep(32)       -- rewritten
      local B = "bbbbbbb2" .. ("1"):rep(32)       -- rewritten; new id collides
      local C = "ccccccc3" .. ("2"):rep(32)       -- not in the map
      local D1 = "ddddddd4" .. ("3"):rep(32)      -- two commits share a prefix
      local D2 = "ddddddd4" .. ("4"):rep(32)
      local N = "1234567" .. ("5"):rep(33)        -- all digits in its first 7
      local A2 = "eeeeeee5" .. ("6"):rep(32)
      local B2 = "fffffff6" .. ("7"):rep(32)
      local B2x = "fffffff6" .. ("8"):rep(32)     -- makes B2's 8-char prefix ambiguous
      local before = q.new_universe()
      for _, id in ipairs({A, B, C, D1, D2, N}) do q.universe_add(before, id) end
      local after = q.new_universe()
      for _, id in ipairs({A, B, C, D1, D2, N, A2, B2, B2x}) do q.universe_add(after, id) end
      local N2 = "9999999a" .. ("9"):rep(32)
      q.universe_add(after, N2)
      local map = { [A] = A2, [B] = B2, [N] = N2 }
      local ctx = { before = before, after = after, lookup = function(o) return map[o] or o end }
      local function rw(t) return (q.rewrite(t, ctx)) end

      check("full id rewritten", rw("see " .. A .. ".") == "see " .. A2 .. ".")
      check("short id keeps its length", rw("fix aaaaaaa1 done") == "fix eeeeeee5 done")
      check("7-char id rewritten", rw("(aaaaaaa)") == "(eeeeeee)")
      check("ambiguous prefix left", rw("ddddddd4 x") == "ddddddd4 x")
      check("unmapped commit left", rw("ccccccc3") == "ccccccc3")
      check("all-digit token left", rw("on 1234567 at") == "on 1234567 at")
      check("inside a word left", rw("xaaaaaaa1 aaaaaaa1y") == "xaaaaaaa1 aaaaaaa1y")
      check("64-hex run left", rw(("a"):rep(64)) == ("a"):rep(64))
      check("uppercase neighbour left", rw("Gaaaaaaa1") == "Gaaaaaaa1")
      local out, stats = q.rewrite("id bbbbbbb2 here", ctx)
      check("ambiguous new prefix lengthened", out == "id fffffff67 here" and stats.lengthened == 1)
      local rev = {}; for o, n in pairs(map) do rev[n] = o end
      local back = q.rewrite(rw("fix aaaaaaa1 and " .. A), { before = after, lookup = function(n) return rev[n] or n end })
      check("reverse rewrite restores", back == "fix aaaaaaa1 and " .. A)
      -- An 8-digit id is a commit like any other; a 7-character new id that
      -- would be all digits grows to 8 so the rule above can find it again,
      -- and the reverse check restores the original either way.
      local E = "eeeeeee7" .. ("a"):rep(32)
      local E2 = "1234567" .. "89b" .. ("c"):rep(30)
      local G = "87654321" .. ("d"):rep(32)
      local G2 = "abababab" .. ("e"):rep(32)
      for _, id in ipairs({E, G}) do q.universe_add(before, id); q.universe_add(after, id) end
      q.universe_add(after, E2); q.universe_add(after, G2)
      map[E] = E2; rev[E2] = E; map[G] = G2; rev[G2] = G
      check("8-digit id rewritten", rw("sha 87654321 ok") == "sha abababab ok")
      local out2, st2 = q.rewrite("at eeeeeee ok", ctx)
      check("7-char all-digit new id grows to 8", out2 == "at 12345678 ok" and st2.lengthened == 1)
      local back2 = q.rewrite(out2 .. " sha abababab", { before = after, lookup = function(n) return rev[n] or n end,
         out_len = function(t) return st2.restore_len[t] or #t end })
      check("reverse restores lengthened and 8-digit ids", back2 == "at eeeeeee ok sha 87654321")
      check("sound map has no problems", #q.map_problems({ [A] = A2, [C] = C }) == 0)
      check("shared twin detected", #q.map_problems({ [A] = A2, [B] = A2 }) == 1)
      check("short id in map detected", #q.map_problems({ [A] = "abc" }) == 1)
      print(string.format("  %d passed, %d failed", pass, fail))
      os.exit(fail == 0 and 0 or 1)
LUA
}
# }}}

# {{{ commit_at
# Commits with a fixed author and date, so the test can check both survive.
commit_at() {
   local repo="$1" date="$2" msg="$3"
   GIT_AUTHOR_NAME="Tester" GIT_AUTHOR_EMAIL="t@example" GIT_AUTHOR_DATE="${date}" \
   GIT_COMMITTER_NAME="Tester" GIT_COMMITTER_EMAIL="t@example" GIT_COMMITTER_DATE="${date}" \
      git -C "${repo}" commit -q --no-verify -m "${msg}"
}
# }}}

# {{{ build_fixture
build_fixture() {
   rm -rf "${T}"
   mkdir -p "${T}"
   # Project alpha: its own repository, three commits, read from a bundle.
   git init -q -b main "${T}/alpha"
   echo one > "${T}/alpha/a.txt"; git -C "${T}/alpha" add a.txt; commit_at "${T}/alpha" "1700000000 -0700" "alpha begins"
   echo two >> "${T}/alpha/a.txt"; git -C "${T}/alpha" add a.txt; commit_at "${T}/alpha" "1700001000 -0700" "alpha grows"
   echo three >> "${T}/alpha/a.txt"; git -C "${T}/alpha" add a.txt; commit_at "${T}/alpha" "1700002000 -0700" "alpha settles"
   git -C "${T}/alpha" bundle create -q "${T}/alpha.bundle" main
   # Project beta: a repository read directly, stopping before its last commit.
   git init -q -b main "${T}/beta"
   echo b1 > "${T}/beta/b.txt"; git -C "${T}/beta" add b.txt; commit_at "${T}/beta" "1700003000 -0700" "beta begins"
   BETA_STOP=$(git -C "${T}/beta" rev-parse HEAD)
   echo b2 >> "${T}/beta/b.txt"; git -C "${T}/beta" add b.txt; commit_at "${T}/beta" "1700009000 -0700" "beta after the import"

   # The monorepo: its first commit gathers both (alpha plus one new file).
   git init -q -b main "${T}/mono"
   mkdir -p "${T}/mono/alpha" "${T}/mono/beta" "${T}/mono/notes"
   git -C "${T}/alpha" archive main | tar -x -C "${T}/mono/alpha"
   echo extra > "${T}/mono/alpha/extra.txt"
   git -C "${T}/beta" archive "${BETA_STOP}" | tar -x -C "${T}/mono/beta"
   git -C "${T}/mono" add -A; commit_at "${T}/mono" "1700005000 -0700" "Initial commit: collection"
   JOIN=$(git -C "${T}/mono" rev-parse HEAD)
   ALPHA_FIRST=$(git -C "${T}/alpha" rev-list --max-parents=0 main)
   printf 'import was %s, alpha began at %s, digits 1234567, word x%sy\n' \
      "${JOIN:0:8}" "${ALPHA_FIRST}" "${JOIN:0:8}" > "${T}/mono/notes/n.md"
   git -C "${T}/mono" add -A; commit_at "${T}/mono" "1700006000 -0700" "notes quoting ${JOIN:0:9}"
   SECOND=$(git -C "${T}/mono" rev-parse HEAD)
   git -C "${T}/mono" tag -a v1 -m "release one" "${SECOND}"
   echo more >> "${T}/mono/notes/n.md"
   git -C "${T}/mono" add -A; commit_at "${T}/mono" "1700007000 -0700" "follow-up to ${SECOND:0:8}"

   printf 'alpha %s refs/heads/main\nbeta %s %s\n' "${T}/alpha.bundle" "${T}/beta" "${BETA_STOP}" > "${T}/projects"
}
# }}}

# {{{ integration_tests
integration_tests() {
   echo "prepare on a toy monorepo"
   build_fixture
   local out
   if out=$("${TOOL}" prepare --dir "${T}/mono" --work "${T}/work" --projects "${T}/projects" \
         --join "${JOIN}" --carry-tags v1 2>&1); then check "prepare succeeds, all gates pass" yes
   else printf '%s\n' "${out}" | tail -15; check "prepare succeeds, all gates pass" no; return; fi
   local S="${T}/work/repo.git"
   check "4 moved commits (3 alpha + 1 beta)" "$(yn [ "$(wc -l < "${T}/work/folder.map")" -eq 4 ])"
   check "rebuilt trunk has 3 + 4 commits" "$(yn [ "$(git --git-dir="${S}" rev-list --count main)" -eq 7 ])"
   check "alpha's path log reaches its first commit" \
      "$(yn [ "$(git --git-dir="${S}" log --format=%s main -- alpha/ | tail -1)" = "alpha begins" ])"
   check "alpha's first commit keeps its date" \
      "$(yn [ "$(git --git-dir="${S}" log --format=%ad --date=raw main -- alpha/ | tail -1)" = "1700000000 -0700" ])"
   local new_join new_second
   new_join=$(grep "^${JOIN} " "${T}/work/commits.map" | cut -d' ' -f2)
   new_second=$(grep "^${SECOND} " "${T}/work/commits.map" | cut -d' ' -f2)
   check "join commit has two parents" "$(yn [ "$(git --git-dir="${S}" log -1 --format=%P "${new_join}" | wc -w)" -eq 2 ])"
   check "message quote rewritten (9 chars kept)" \
      "$(yn [ "$(git --git-dir="${S}" log -1 --format=%s "${new_second}")" = "notes quoting ${new_join:0:9}" ])"
   check "tag v1 follows its commit" "$(yn [ "$(git --git-dir="${S}" rev-parse 'v1^{commit}')" = "${new_second}" ])"
   local note
   note=$(git --git-dir="${S}" show quoted:notes/n.md)
   check "file quote rewritten, same length" "$(yn grep -q "import was ${new_join:0:8}," <<< "${note}")"
   check "project commit quote rewritten to full id" \
      "$(yn grep -q "alpha began at $(grep "^${ALPHA_FIRST} " "${T}/work/commits.map" | cut -d' ' -f2)" <<< "${note}")"
   check "digits and embedded runs untouched" "$(yn grep -q "digits 1234567, word x${JOIN:0:8}y" <<< "${note}")"
   check "map committed with the quote commit" \
      "$(yn git --git-dir="${S}" cat-file -e quoted:delta-version/archive/history-graft/commits.map)"
   check "real toy repo untouched by prepare" "$(yn [ "$(git -C "${T}/mono" rev-parse main)" != "$(git --git-dir="${S}" rev-parse main)" ])"

   echo "swap on the toy monorepo"
   check "swap refuses without the flag" "$(yn fails quiet "${TOOL}" swap --dir "${T}/mono" --work "${T}/work" --projects "${T}/projects" --carry-tags v1)"
   if command -v script > /dev/null; then
      printf 'rewrite main\n' | script -qec "'${TOOL}' swap --dir '${T}/mono' --work '${T}/work' --projects '${T}/projects' --join ${JOIN} --carry-tags v1 --i-understand-this-rewrites-history" /dev/null > "${T}/swap.out" 2>&1 || true
      check "swap moves main to the quote commit" \
         "$(yn [ "$(git -C "${T}/mono" rev-parse main)" = "$(git --git-dir="${S}" rev-parse quoted)" ])"
      check "old trunk archived" "$(yn [ "$(git -C "${T}/mono" rev-parse archive/main-before-history-graft)" = "$(git --git-dir="${S}" rev-parse old-main)" ])"
      check "working tree matches new main" "$(yn git -C "${T}/mono" diff --quiet HEAD)"
      check "file on disk carries new ids" "$(yn grep -q "import was ${new_join:0:8}," "${T}/mono/notes/n.md")"
      check "swap printed push commands, did not push" "$(yn grep -q 'push --force-with-lease' "${T}/swap.out")"
      echo "translate after the swap"
      printf 'old import %s\n' "${JOIN:0:8}" > "${T}/loose.md"
      "${TOOL}" translate --dir "${T}/mono" "${T}/loose.md" > /dev/null
      check "translate rewrites a loose file" "$(yn grep -q "old import ${new_join:0:8}" "${T}/loose.md")"
   else
      echo "  (script(1) missing: swap success path not exercised)"
   fi
}
# }}}

# {{{ main
UNIT_OK=yes
unit_tests || UNIT_OK=no
check "unit tests" "${UNIT_OK}"
integration_tests
echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
# }}}
