# libs/project-discovery.lua and libs/project-discovery.sh

Which folders in a folder of projects are projects, how much each looks like
one, and what kind each is. The rules are delta-version's
`scripts/list-projects.sh`'s, lifted into one shared place (issue 010).

The Lua file is the only copy of the rules. The bash file runs it and puts
its answers into arrays, so a bash script and a Lua script cannot disagree.

## The rules

- **Folders directly inside the base folder**, sorted by name. The base
  itself is never listed, and symbolic links to folders are not followed.
- **Skipped by name** (shell-style globs on the folder's own name): issues,
  scripts, docs, .git, .claude, llm-transcripts, build, target, dist, out,
  bin, libs, node_modules, vendor, external, tools, utils, backup, backups,
  old, archive, tmp, temp, delta-version, .operations, .canaries,
  .storage_\*, .\*_operations\*.
- **Scored by the marks it has:** src/ 50, issues/ 40, Cargo.toml 30,
  package.json 30, Makefile 25, .gitignore 20, README.md 15, docs/ 10. A
  folder with **50 or more** is a project.
- **Kind:** the build file it keeps settles it (Cargo.toml rust, go.mod go,
  package.json node, pyproject.toml / setup.py / requirements.txt python, a
  .rockspec lua); otherwise the kind of source file it holds most of, in the
  folder and in src/ two levels down (.lua, .c/.h, .cpp/.hpp/.cc, .rs, .go,
  .py, .js/.ts, .sh, .zig), a tie going to the kind first alphabetically;
  otherwise `unknown` (most often a project of plans and docs so far).

## Lua

    local d = dofile(SCRIPTS_DIR .. "/libs/project-discovery.lua")
    d.init(base_dir, options)   -- options: excluded, exclude, weights, threshold
    d.scan(include_all)         -- list of { path, name, score, marks, type,
                                --           excluded, is_project }
    d.examine(path)             -- the same table for one folder
    d.score(path)               -- points, list of marks found
    d.classify(path)            -- kind string
    d.is_excluded(path)         -- true when its name rules it out

`options.excluded` replaces the skipped names; `options.exclude` adds to
them; `options.weights` is `{ mark = points }` (a new mark counts as a folder
when it has no dot); `options.threshold` replaces 50.

Run as a command (what the bash face does):

    luajit project-discovery.lua scan BASE [--all] [--exclude G] [--only-exclude G]
                                           [--weight MARK=N] [--threshold N]
    luajit project-discovery.lua score PATH
    luajit project-discovery.lua classify PATH

`scan` prints path, name, score and kind separated by tabs; `--all` lists
every folder with a fifth column, `project`, `not-project` or `excluded`.
Exit 2 on bad arguments or a base that is not a folder. Works under luajit
and lua5.4.

## Bash

    source "${SCRIPTS_DIR}/libs/project-discovery.sh"
    project_discovery_init "$base"
    PROJECT_DISCOVERY_EXCLUDE=(...)      # optional, after init
    project_discovery_scan || exit 1     # DISCOVERED_PROJECTS, PROJECT_SCORES[p], PROJECT_TYPES[p]
    project_discovery_score "$path"
    project_discovery_classify "$path"
    project_discovery_is_project "$path" && ...

Settings: `PROJECT_DISCOVERY_EXCLUDE`, `PROJECT_DISCOVERY_ONLY_EXCLUDE`,
`PROJECT_DISCOVERY_WEIGHTS` (`mark=points` words),
`PROJECT_DISCOVERY_THRESHOLD`. `project_discovery_init` resets them all.

## Agreement with list-projects.sh

On the monorepo (2026-11-02) both list the same 41 projects. The one
deliberate difference: list-projects.sh's `find` also visits the base folder,
so a base that scores 50 or more lists itself; this library never does.
`list-projects.sh` does not use this library yet -- that change is
delta-version's to make.

Tested by `tests/test-project-discovery.sh`.
