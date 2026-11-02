# libs/issue-manager.lua and libs/issue-manager.sh

The everyday operations on any project's issue files: the next number, a
listing, a new issue, moving one to `completed/`, checking one, and searching
them (issue 012).

It reads names through `libs/issue-names.lua` (the reader the progress
dashboard and `validate-issues` share), numbers new issues by that file's
`next_id`, and checks issues by running `validate-issues --file`. So the
three tools cannot disagree about phases, numbers or what a well-formed
issue is.

It never stages or commits. Completing is a plain rename on disk; the commit
route picks the move up from the files, and the shared staging area is left
to the sessions that share it.

## Bash

    source "${SCRIPTS_DIR}/libs/issue-manager.sh"
    issue_init DIR                       # fails (2) without DIR/issues
    issue_get_next_id PHASE              # 308, 9-014, A08 ...
    issue_list [STATUS] [PHASE]          # id, phase, status, path under issues/ (tabs)
    issue_path ID                        # full path
    issue_create ID NAME [< body]        # prints the new path
    issue_complete ID                    # prints the new path
    issue_validate ID                    # prints findings; fails when there are any
    issue_search WORDS...                # path:line: text

`issue_create` takes the body from standard input when it is not a terminal;
when it is, or nothing arrives, the file gets a template: a title and the
three headings `validate-issues` requires.

Every function prints its reason for refusing on stderr and returns 1 (2 for
bad arguments or no `issues/`).

## Lua

    local issues = dofile(SCRIPTS_DIR .. "/libs/issue-manager.lua")
    issues.init(dir)                     -- raises without dir/issues
    issues.next_id(phase)                -- string
    issues.list({ status =, phase = })   -- issue tables from issue-names, sorted
    issues.find(id)                      -- issue, or nil and why
    issues.create(id, name, body)        -- path, or nil and why
    issues.complete(id)                  -- new path, or nil and why
    issues.validate(id)                  -- true/false, finding lines
    issues.search(query)                 -- { issue, line_number, line } list
    issues.template(id, name)            -- the default body

Run as a command: `luajit issue-manager.lua DIR next PHASE | list [--status S]
[--phase P] | show ID | create ID NAME [-] | complete ID | validate ID |
search WORDS`.

## What it refuses

- **create:** a name that is not lower-case words joined by dashes; an id
  that does not read back as an issue id; an id an open or completed file
  already claims (a superseded or declined file's old id may be reused, as
  `validate-issues` does not count it as a duplicate); a file that exists.
  The id need not be the next free one: a sub-issue (`302a`) or a gap is the
  author's call.
- **complete:** an issue that is not open, does not exist, or whose id two
  files claim; a file of the same name already in `completed/`.

Tested by `tests/test-issue-manager.sh`.
