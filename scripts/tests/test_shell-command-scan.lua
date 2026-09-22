#!/usr/bin/env luajit
-- test_shell-command-scan.lua
--
-- Checks the shell-word reader the gates are built on: that a line of shell is
-- split into the commands a shell would run, with quotes removed, heredoc
-- bodies set aside, redirect targets dropped, and nested scripts (substitution,
-- eval, bash -c, a heredoc fed to a shell) read as commands of their own.
--
-- Each case gives a line and the commands it should produce, written as their
-- effective words joined by single spaces. Exit 0 when all pass, 1 otherwise.
--
-- Usage: test_shell-command-scan.lua [scripts-directory]

local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
package.path = DIR .. "/libs/?.lua;" .. package.path
local scan = require("shell-command-scan")

local failures, checked = 0, 0

-- {{{ local function render()
-- One string per command: its effective words joined by spaces, or "-" for a
-- command whose wrapper means nothing runs (command -v).
local function render(line)
    local out = {}
    for _, cmd in ipairs(scan.all_commands(line)) do
        local words = scan.effective_words(cmd)
        out[#out + 1] = words and table.concat(words, " ") or "-"
    end
    return out
end
-- }}}

-- {{{ local function expect()
local function expect(line, want)
    checked = checked + 1
    local got = render(line)
    local ok = #got == #want
    for i = 1, #want do if got[i] ~= want[i] then ok = false end end
    if ok then
        io.write(string.format("  ok       %s\n", (line:gsub("\n", "\\n"))))
    else
        failures = failures + 1
        io.write(string.format("  FAILED   %s\n    wanted: [%s]\n    got:    [%s]\n",
            (line:gsub("\n", "\\n")), table.concat(want, " | "), table.concat(got, " | ")))
    end
end
-- }}}

io.write("\nSplitting and quotes\n")
expect("ls -la /tmp", { "ls -la /tmp" })
expect("a && b || c; d | e & f", { "a", "b", "c", "d", "e", "f" })
expect([[echo "a; cd b"]], { "echo a; cd b" })
expect([[printf '%s\n' 'x | cd y']], { [[printf %s\n x | cd y]] })
expect([[\cd /tmp]], { "cd /tmp" })
expect([["cd" /tmp]], { "cd /tmp" })
expect([[echo "don't" ; git reset --hard HEAD~1]], { "echo don't", "git reset --hard HEAD~1" })
expect("echo a # cd /tmp\nls", { "echo a", "ls" })
expect("echo a\\\nb", { "echo ab" })

io.write("\nKeywords and prefixes\n")
expect("if true; then cd /tmp; fi", { "true", "cd /tmp" })
expect("while false; do cd /tmp; done", { "false", "cd /tmp" })
expect("! cd /tmp", { "cd /tmp" })
expect("time cd /tmp", { "cd /tmp" })
expect("builtin cd /tmp", { "cd /tmp" })
expect("command cd /tmp", { "cd /tmp" })
expect("command -v cd", { "-" })
expect("FOO=1 BAR=2 cd /tmp", { "cd /tmp" })
expect("env -u X FOO=1 git commit -m y", { "git commit -m y" })
expect("sudo -u root git status", { "git status" })
expect("timeout -s KILL 5 git status", { "git status" })
expect("{ cd /tmp; }", { "cd /tmp" })
expect("find . | xargs -0 -n 1 git add", { "find .", "git add" })

io.write("\nVariables the line sets\n")
checked = checked + 1
local line_commands = scan.all_commands("R=HEAD~1; S=x git reset --hard ${R} $R $UNSET")
local values = scan.assignments(line_commands)
local expanded = {}
for _, w in ipairs(scan.effective_words(line_commands[2])) do
    expanded[#expanded + 1] = scan.expand_known(w, values)
end
if table.concat(expanded, " ") == "git reset --hard HEAD~1 HEAD~1 $UNSET" then
    io.write("  ok       assignments are expanded; unknown variables are left alone\n")
else
    failures = failures + 1
    io.write("  FAILED   assignments: got " .. table.concat(expanded, " ") .. "\n")
end

io.write("\nRedirections\n")
expect("cd>/dev/null /tmp", { "cd /tmp" })
expect("make 2>&1 >log.txt", { "make" })
expect("cat &>out.txt file", { "cat file" })
expect("grep x <<< 'cd /tmp'", { "grep x" })

io.write("\nHeredocs\n")
expect("cat > run.sh <<EOF\ncd \"$(dirname \"$0\")\"\nEOF\nls", { "cat", "ls" })
expect("git commit -F - <<'EOF'\nStop using git commit -a\nEOF", { "git commit -F -" })
expect("bash <<EOF\ncd /tmp\nEOF", { "bash", "cd /tmp" })
expect("cat <<-EOF\n\tcd x\n\tEOF\necho done", { "cat", "echo done" })

io.write("\nNested scripts\n")
-- a line that only assigns runs no command of its own, so it shows as "-"
expect("x=$(cd /x && pwd)", { "-", "cd /x", "pwd" })
expect("echo `cd /tmp`", { "echo `cd /tmp`", "cd /tmp" })
expect("git reset --hard $(git rev-parse HEAD~1)",
    { "git reset --hard $(git rev-parse HEAD~1)", "git rev-parse HEAD~1" })
expect([[eval "cd /tmp"]], { "eval cd /tmp", "cd /tmp" })
expect([[bash -c 'cd /tmp && ls']], { "bash -c cd /tmp && ls", "cd /tmp", "ls" })
expect([[sh -ec "git commit -a"]], { "sh -ec git commit -a", "git commit -a" })
expect("diff <(sort a) b", { "diff <(sort a) b", "sort a" })
expect("echo $((1 + 2))", { "echo $((1 + 2))" })

io.write("\nGit invocation\n")
checked = checked + 1
local inv = scan.git_invocation(scan.effective_words(scan.commands([[git -C "/repo with space" -c a=b --no-pager commit -m x]])[1]))
if inv and inv.subcommand == "commit" and inv.globals[2] == "/repo with space" and #inv.globals == 5 then
    io.write("  ok       git globals and subcommand\n")
else
    failures = failures + 1
    io.write("  FAILED   git globals and subcommand\n")
end

io.write(string.format("\n%d cases, %d failures\n", checked, failures))
os.exit(failures == 0 and 0 or 1)
