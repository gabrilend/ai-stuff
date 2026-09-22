-- shell-command-scan.lua
--
-- Reads a line of shell the way a shell would split it, so the gates in front
-- of Claude Code's shell commands can ask their questions of commands instead
-- of text.
--
-- The gates used to search the raw command text with regular expressions. Text
-- is the wrong thing to search: a word inside quotes is not a command, a heredoc
-- body is not a command, and `if x; then cd y; fi` is a directory change that a
-- search for "cd at the start of a line" never sees. Every bypass and every
-- false refusal the 2026-09-22 review found came from reading text instead of
-- words. This file is the one place that knows how a shell splits a line; each
-- gate then looks at finished words.
--
-- What it understands:
--   quotes ('...', "...", $'...'), backslashes, comments
--   separators: newline ; & && || | |& ( ) and the shell keywords that sit in
--     front of a command (if then else elif fi do done while until ! { } time)
--   redirections, whose target word is not an argument (2>/dev/null, >&2)
--   heredocs: the body is taken away from the command and kept on the side,
--     because text fed to `cat` is data, while text fed to `bash` is commands
--   $( ), backticks, <( ), >( ): their insides are read as commands of their
--     own, and their raw text also stays in the word they sit in, so a revision
--     spelled `$(git rev-parse HEAD~1)` still shows its tilde
--   eval, bash -c / sh -c, and a heredoc fed to a shell: the script they carry
--     is read as more commands
--
-- What it does not: aliases, functions, `source` of a file, a script piped into
-- a shell (`echo ... | bash`), or variables whose values are only known at run
-- time. Those are listed in README-refusal-gates.md as known limits.
--
-- Data shapes:
--   command = {
--     words    = { string, ... }  -- finished words, quotes removed
--     heredocs = { { body = string, delimiter = string }, ... }
--     depth    = integer          -- 0 for the top line, +1 per nesting
--   }
--
-- LuaJIT compatible; no Lua 5.4 syntax.

local scan = {}

-- Words that put something in front of a command without being the command.
-- A word here, at the start of a command, is dropped as if it were a separator.
-- `time` and `!` modify the command after them; the rest are grammar.
local RESERVED_AT_COMMAND_START = {
    ["if"] = true, ["then"] = true, ["else"] = true, ["elif"] = true,
    ["fi"] = true, ["do"] = true, ["done"] = true, ["while"] = true,
    ["until"] = true, ["!"] = true, ["{"] = true, ["}"] = true,
    ["time"] = true, ["[["] = false,
}

-- The shells whose -c argument, or whose heredoc, is itself a script.
local SHELL_INTERPRETERS = {
    bash = true, sh = true, zsh = true, dash = true, ksh = true, mksh = true,
    ash = true, busybox = false,
}

-- Nesting guard. A line that nests eval inside bash -c inside $( ) past this
-- depth is not something anybody types by accident.
local MAX_DEPTH = 8

-- {{{ local function new_command()
local function new_command(depth)
    return { words = {}, heredocs = {}, depth = depth }
end
-- }}}

-- {{{ local function capture_balanced()
-- Walks from just after an opening bracket to its matching close, skipping
-- quoted spans and escaped characters, and returns the inside text and the
-- position after the close. An unclosed bracket runs to the end of the text,
-- which is what a shell would complain about; the gate reads what is there.
local function capture_balanced(text, pos, open_char, close_char)
    local depth = 1
    local start = pos
    local n = #text
    while pos <= n do
        local c = text:sub(pos, pos)
        if c == "\\" then
            pos = pos + 2
        elseif c == "'" then
            local close = text:find("'", pos + 1, true)
            pos = (close or n) + 1
        elseif c == '"' then
            -- a double-quoted span inside the brackets; backslashes escape
            local p = pos + 1
            while p <= n do
                local d = text:sub(p, p)
                if d == "\\" then p = p + 2
                elseif d == '"' then break
                else p = p + 1 end
            end
            pos = p + 1
        elseif c == open_char then
            depth = depth + 1
            pos = pos + 1
        elseif c == close_char then
            depth = depth - 1
            if depth == 0 then
                return text:sub(start, pos - 1), pos + 1
            end
            pos = pos + 1
        else
            pos = pos + 1
        end
    end
    return text:sub(start), n + 1
end
-- }}}

-- {{{ local function capture_backticks()
-- Backtick substitution: runs to the next unescaped backtick. Inside, \` is a
-- literal backtick in the inner script.
local function capture_backticks(text, pos)
    local parts = {}
    local n = #text
    while pos <= n do
        local c = text:sub(pos, pos)
        if c == "\\" and pos < n then
            local d = text:sub(pos + 1, pos + 1)
            -- \` \\ \$ lose their backslash inside backticks; others keep it
            if d == "`" or d == "\\" or d == "$" then
                parts[#parts + 1] = d
            else
                parts[#parts + 1] = c .. d
            end
            pos = pos + 2
        elseif c == "`" then
            return table.concat(parts), pos + 1
        else
            parts[#parts + 1] = c
            pos = pos + 1
        end
    end
    return table.concat(parts), n + 1
end
-- }}}

-- {{{ function scan.commands()
-- Splits one piece of shell text into commands. Nested scripts (substitutions,
-- eval, bash -c, heredocs fed to a shell) are read too and appended after the
-- command that carries them, one level deeper.
function scan.commands(text, depth)
    depth = depth or 0
    local commands = {}
    if depth > MAX_DEPTH then
        return commands
    end

    local n = #text
    local pos = 1
    local current = new_command(depth)
    local word = nil            -- the word being built, or nil between words
    local word_quoted = false   -- did any part of this word come from quotes?
    local skip_next_word = false -- the next finished word is a redirect target
    local heredoc_next = nil    -- the next finished word is a heredoc delimiter
    local pending_heredocs = {} -- delimiters waiting for the next newline
    local nested_scripts = {}   -- inner scripts to read after this line

    -- {{{ local function append()
    local function append(s, quoted)
        word = (word or "") .. s
        if quoted then word_quoted = true end
    end
    -- }}}

    -- {{{ local function finish_word()
    -- A finished word goes to one of four places: a heredoc delimiter, a
    -- redirection target (dropped), dropped as a keyword at command start, or
    -- the command's word list.
    local function finish_word()
        if word == nil then return end
        local w, quoted = word, word_quoted
        word, word_quoted = nil, false
        if heredoc_next then
            -- the delimiter: body collected at the next newline
            heredoc_next.delimiter = w
            pending_heredocs[#pending_heredocs + 1] = heredoc_next
            heredoc_next = nil
        elseif skip_next_word then
            -- a redirection target is where output goes, not an argument
            skip_next_word = false
        elseif #current.words == 0 and not quoted and RESERVED_AT_COMMAND_START[w] then
            -- grammar in front of a command; the command starts after it
        else
            current.words[#current.words + 1] = w
        end
    end
    -- }}}

    -- {{{ local function finish_command()
    local function finish_command()
        finish_word()
        if #current.words > 0 or #current.heredocs > 0 then
            commands[#commands + 1] = current
        end
        current = new_command(depth)
    end
    -- }}}

    -- {{{ local function read_heredoc_bodies()
    -- Called just after a newline: every heredoc opened on the line before
    -- takes its body now, in the order they were opened.
    local function read_heredoc_bodies()
        for _, pending in ipairs(pending_heredocs) do
            local body = {}
            while pos <= n do
                local line_end = text:find("\n", pos, true) or (n + 1)
                local line = text:sub(pos, line_end - 1)
                pos = line_end + 1
                local compare = line
                if pending.strip_tabs then compare = line:gsub("^\t+", "") end
                if compare == pending.delimiter then break end
                body[#body + 1] = line
            end
            local attached = pending.command.heredocs
            attached[#attached + 1] = {
                body = table.concat(body, "\n"),
                delimiter = pending.delimiter,
            }
        end
        pending_heredocs = {}
    end
    -- }}}

    -- {{{ local function read_dollar()
    -- Everything that starts with $: command substitution, arithmetic,
    -- parameter expansion, ANSI-C quoting, or a plain dollar sign.
    local function read_dollar(in_double_quotes)
        local nxt = text:sub(pos + 1, pos + 1)
        if nxt == "(" and text:sub(pos + 2, pos + 2) == "(" then
            -- $(( arithmetic )): a number, never a command
            local inner, after = capture_balanced(text, pos + 3, "(", ")")
            append("$((" .. inner .. ")", in_double_quotes)
            pos = after
            if text:sub(pos, pos) == ")" then append(")") ; pos = pos + 1 end
        elseif nxt == "(" then
            -- $( command ): read the inside as commands, keep the raw text
            local inner, after = capture_balanced(text, pos + 2, "(", ")")
            append("$(" .. inner .. ")", in_double_quotes)
            nested_scripts[#nested_scripts + 1] = inner
            pos = after
        elseif nxt == "{" then
            -- ${ parameter }: a value, kept as text
            local inner, after = capture_balanced(text, pos + 2, "{", "}")
            append("${" .. inner .. "}", in_double_quotes)
            pos = after
        elseif nxt == "'" and not in_double_quotes then
            -- $'ANSI-C': escapes decoded roughly; enough to read the words
            local p = pos + 2
            local parts = {}
            while p <= n do
                local d = text:sub(p, p)
                if d == "\\" then
                    local e = text:sub(p + 1, p + 1)
                    local decoded = ({ n = "\n", t = "\t", ["'"] = "'", ["\\"] = "\\" })[e]
                    parts[#parts + 1] = decoded or ("\\" .. e)
                    p = p + 2
                elseif d == "'" then
                    break
                else
                    parts[#parts + 1] = d
                    p = p + 1
                end
            end
            append(table.concat(parts), true)
            pos = p + 1
        else
            -- a plain dollar: $VAR, $1, or a lone $
            append("$", in_double_quotes)
            pos = pos + 1
        end
    end
    -- }}}

    -- {{{ local function read_double_quotes()
    local function read_double_quotes()
        pos = pos + 1
        word = word or ""
        word_quoted = true
        while pos <= n do
            local c = text:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return
            elseif c == "\\" then
                local d = text:sub(pos + 1, pos + 1)
                if d == "\n" then
                    -- line continuation inside quotes: both characters vanish
                elseif d == "$" or d == "`" or d == '"' or d == "\\" then
                    append(d, true)
                else
                    append("\\" .. d, true)
                end
                pos = pos + 2
            elseif c == "$" then
                read_dollar(true)
            elseif c == "`" then
                local inner, after = capture_backticks(text, pos + 1)
                append("`" .. inner .. "`", true)
                nested_scripts[#nested_scripts + 1] = inner
                pos = after
            else
                append(c, true)
                pos = pos + 1
            end
        end
    end
    -- }}}

    -- {{{ local function read_redirection()
    -- < > and their friends. A number just before it (2>) is a file descriptor,
    -- not a word. The word after it is a target, not an argument -- except for
    -- a heredoc, where it is the delimiter.
    local function read_redirection()
        if word ~= nil and word:match("^%d+$") and not word_quoted then
            word = nil
        else
            finish_word()
        end
        local rest = text:sub(pos, pos + 2)
        if rest:sub(1, 2) == "<(" or rest:sub(1, 2) == ">(" then
            -- process substitution: a command whose output is a file name
            local inner, after = capture_balanced(text, pos + 2, "(", ")")
            append(rest:sub(1, 2) .. inner .. ")")
            nested_scripts[#nested_scripts + 1] = inner
            pos = after
            return
        end
        if rest == "<<<" then
            -- here-string: the next word is data
            pos = pos + 3
            skip_next_word = true
        elseif rest:sub(1, 3) == "<<-" then
            pos = pos + 3
            heredoc_next = { strip_tabs = true, command = current }
        elseif rest:sub(1, 2) == "<<" then
            pos = pos + 2
            heredoc_next = { strip_tabs = false, command = current }
        else
            -- > >> >| >& <& <> < : consume the operator characters, then the
            -- target word is dropped when it finishes
            local op = text:match("^[<>][<>|&]?", pos)
            pos = pos + #op
            skip_next_word = true
        end
    end
    -- }}}

    -- The dispatch table: one handler per character that means something to a
    -- shell. Anything not in it is part of the current word.
    local handlers = {}

    -- {{{ whitespace
    handlers[" "] = function() finish_word(); pos = pos + 1 end
    handlers["\t"] = handlers[" "]
    -- }}}

    -- {{{ newline
    handlers["\n"] = function()
        finish_command()
        pos = pos + 1
        if #pending_heredocs > 0 then read_heredoc_bodies() end
    end
    -- }}}

    -- {{{ separators
    handlers[";"] = function() finish_command(); pos = pos + 1 end
    handlers["("] = handlers[";"]
    handlers[")"] = handlers[";"]
    handlers["|"] = function()
        finish_command()
        local nxt = text:sub(pos + 1, pos + 1)
        pos = pos + ((nxt == "|" or nxt == "&") and 2 or 1)
    end
    handlers["&"] = function()
        local nxt = text:sub(pos + 1, pos + 1)
        if nxt == ">" then
            -- &> and &>> redirect both streams; the target is not an argument
            finish_word()
            pos = pos + (text:sub(pos + 2, pos + 2) == ">" and 3 or 2)
            skip_next_word = true
        else
            finish_command()
            pos = pos + (nxt == "&" and 2 or 1)
        end
    end
    -- }}}

    -- {{{ redirections
    handlers["<"] = read_redirection
    handlers[">"] = read_redirection
    -- }}}

    -- {{{ quoting
    handlers["'"] = function()
        local close = text:find("'", pos + 1, true) or (n + 1)
        append(text:sub(pos + 1, close - 1), true)
        pos = close + 1
    end
    handlers['"'] = read_double_quotes
    handlers["\\"] = function()
        local d = text:sub(pos + 1, pos + 1)
        if d == "\n" then
            -- line continuation: the command goes on to the next line
        elseif d ~= "" then
            append(d, true)
        end
        pos = pos + 2
    end
    -- }}}

    -- {{{ substitutions
    handlers["$"] = function() read_dollar(false) end
    handlers["`"] = function()
        local inner, after = capture_backticks(text, pos + 1)
        append("`" .. inner .. "`")
        nested_scripts[#nested_scripts + 1] = inner
        pos = after
    end
    -- }}}

    -- {{{ comments
    handlers["#"] = function()
        if word == nil then
            -- a comment runs to the end of the line; the newline still counts
            local line_end = text:find("\n", pos, true) or (n + 1)
            pos = line_end
        else
            append("#")
            pos = pos + 1
        end
    end
    -- }}}

    while pos <= n do
        local c = text:sub(pos, pos)
        local handler = handlers[c]
        if handler then
            handler()
        else
            append(c)
            pos = pos + 1
        end
    end
    finish_command()

    -- Nested scripts carried by this line's words are read after it, deeper.
    for _, inner in ipairs(nested_scripts) do
        for _, cmd in ipairs(scan.commands(inner, depth + 1)) do
            commands[#commands + 1] = cmd
        end
    end
    return commands
end
-- }}}

-- {{{ local function skip_options()
-- Steps past a wrapper's own options. `with_value` lists the options that take
-- the next word as their value. Returns the index of the first non-option word.
local function skip_options(words, i, with_value)
    while words[i] and words[i]:sub(1, 1) == "-" and words[i] ~= "-" do
        if words[i] == "--" then return i + 1 end
        if with_value[words[i]] then i = i + 2 else i = i + 1 end
    end
    return i
end
-- }}}

-- What each wrapper word does to the words after it. Each handler is given the
-- word list and the wrapper's index, and returns the index where the real
-- command starts -- or nil when the wrapper means "do not run anything"
-- (`command -v cd` only looks cd up).
local PREFIX_HANDLERS = {
    builtin = function(words, i) return i + 1 end,
    nohup = function(words, i) return i + 1 end,
    ["time"] = function(words, i) return skip_options(words, i + 1, {}) end,
    command = function(words, i)
        local j = i + 1
        while words[j] and words[j]:sub(1, 1) == "-" do
            if words[j]:find("[vV]") then return nil end
            j = j + 1
        end
        return j
    end,
    exec = function(words, i) return skip_options(words, i + 1, { ["-a"] = true }) end,
    env = function(words, i)
        local j = skip_options(words, i + 1, {
            ["-u"] = true, ["--unset"] = true, ["-C"] = true, ["--chdir"] = true,
            ["-S"] = true, ["--split-string"] = true,
        })
        while words[j] and words[j]:match("^[%a_][%w_]*=") do j = j + 1 end
        return j
    end,
    nice = function(words, i) return skip_options(words, i + 1, { ["-n"] = true }) end,
    sudo = function(words, i)
        return skip_options(words, i + 1, {
            ["-u"] = true, ["-g"] = true, ["-h"] = true, ["-p"] = true, ["-C"] = true,
            ["-D"] = true, ["-r"] = true, ["-t"] = true, ["-U"] = true, ["-T"] = true,
        })
    end,
    doas = function(words, i) return skip_options(words, i + 1, { ["-u"] = true, ["-C"] = true }) end,
    timeout = function(words, i)
        local j = skip_options(words, i + 1, { ["-s"] = true, ["--signal"] = true, ["-k"] = true, ["--kill-after"] = true })
        return j + 1 -- the duration
    end,
    stdbuf = function(words, i) return skip_options(words, i + 1, { ["-i"] = true, ["-o"] = true, ["-e"] = true }) end,
    -- xargs runs its command with extra arguments read from input; the words
    -- that follow its options are still the command it runs
    xargs = function(words, i)
        return skip_options(words, i + 1, {
            ["-n"] = true, ["-I"] = true, ["-L"] = true, ["-P"] = true, ["-d"] = true,
            ["-a"] = true, ["-E"] = true, ["-s"] = true, ["--max-args"] = true,
            ["--max-procs"] = true, ["--delimiter"] = true, ["--arg-file"] = true,
        })
    end,
}

-- {{{ function scan.effective_words()
-- The words of a command from its real command word onward: assignments in
-- front (NAME=value) and wrappers (env, command, builtin, sudo, ...) are
-- stepped past. Returns nil when there is no command to run.
function scan.effective_words(command)
    local words = command.words
    local i = 1
    while words[i] do
        local w = words[i]
        if w:match("^[%a_][%w_]*%+?=") then
            i = i + 1
        elseif PREFIX_HANDLERS[w] then
            i = PREFIX_HANDLERS[w](words, i)
            if i == nil then return nil end
        else
            break
        end
    end
    if not words[i] then return nil end
    local out = {}
    for j = i, #words do out[#out + 1] = words[j] end
    return out
end
-- }}}

-- {{{ function scan.assignments()
-- The variables a line sets (NAME=value at the start of a command, including
-- a command that is only assignments), so a gate can see what `$NAME` will
-- hold later on the same line. A value set by a command's output or outside
-- the line is not known, and is simply absent.
function scan.assignments(commands)
    local values = {}
    for _, command in ipairs(commands) do
        for _, w in ipairs(command.words) do
            local name, value = w:match("^([%a_][%w_]*)=(.*)$")
            if not name then break end
            values[name] = value
        end
    end
    return values
end
-- }}}

-- {{{ function scan.expand_known()
-- Replaces $NAME and ${NAME} in a word with values the line itself set.
-- Unknown variables are left as written.
function scan.expand_known(word, values)
    word = word:gsub("%${([%a_][%w_]*)}", function(n) return values[n] end)
    word = word:gsub("%$([%a_][%w_]*)", function(n) return values[n] end)
    return word
end
-- }}}

-- {{{ function scan.command_name()
-- The program a command word names: /usr/bin/git and git are both git.
function scan.command_name(word)
    return (word:match("([^/]+)$")) or word
end
-- }}}

-- {{{ local function inner_scripts()
-- The scripts a command carries that a shell will run as commands: the words
-- of eval, the argument of bash -c, and a heredoc fed to a shell.
local function inner_scripts(command)
    local words = scan.effective_words(command)
    if not words then return {} end
    local name = scan.command_name(words[1])
    local scripts = {}
    if name == "eval" then
        scripts[1] = table.concat(words, " ", 2)
    elseif SHELL_INTERPRETERS[name] then
        local has_c = false
        local i = 2
        while words[i] and words[i]:sub(1, 1) == "-" and words[i] ~= "--" do
            -- -c on its own or inside a cluster like -ec or -lc
            if words[i]:sub(2, 2) ~= "-" and words[i]:find("c", 2, true) then
                has_c = true
            end
            i = i + 1
        end
        if has_c and words[i] then
            scripts[#scripts + 1] = words[i]
        elseif not has_c then
            -- no -c: a heredoc fed to the shell is its script
            for _, doc in ipairs(command.heredocs) do
                scripts[#scripts + 1] = doc.body
            end
        end
    end
    return scripts
end
-- }}}

-- {{{ function scan.all_commands()
-- Every command a line would run: the line's own commands, the insides of
-- substitutions, and the scripts carried by eval, bash -c and shell heredocs,
-- read recursively up to the nesting guard.
function scan.all_commands(text)
    local out = {}
    local queue = scan.commands(text, 0)
    local k = 1
    while queue[k] do
        local command = queue[k]
        out[#out + 1] = command
        if command.depth < MAX_DEPTH then
            for _, script in ipairs(inner_scripts(command)) do
                for _, inner in ipairs(scan.commands(script, command.depth + 1)) do
                    queue[#queue + 1] = inner
                end
            end
        end
        k = k + 1
    end
    return out
end
-- }}}

-- {{{ function scan.git_invocation()
-- Splits a git command into its global options and its subcommand. Returns
-- nil when the command is not git. `globals` keeps the options as typed, so a
-- caller can re-run git against the same repository the command would use.
--
-- Global options that take the next word as their value are listed; every
-- other word starting with - before the subcommand is a flag (-P, --bare,
-- --no-optional-locks, --git-dir=x, ...).
local GIT_GLOBALS_WITH_VALUE = {
    ["-C"] = true, ["-c"] = true, ["--git-dir"] = true, ["--work-tree"] = true,
    ["--namespace"] = true, ["--config-env"] = true, ["--super-prefix"] = true,
    ["--attr-source"] = true, ["--list-cmds"] = true,
}
function scan.git_invocation(words)
    if not words or scan.command_name(words[1]) ~= "git" then return nil end
    local globals = {}
    local i = 2
    while words[i] and words[i]:sub(1, 1) == "-" do
        globals[#globals + 1] = words[i]
        if GIT_GLOBALS_WITH_VALUE[words[i]] and words[i + 1] then
            globals[#globals + 1] = words[i + 1]
            i = i + 2
        else
            i = i + 1
        end
    end
    if not words[i] then return nil end
    local args = {}
    for j = i + 1, #words do args[#args + 1] = words[j] end
    return { globals = globals, subcommand = words[i], args = args }
end
-- }}}

return scan
