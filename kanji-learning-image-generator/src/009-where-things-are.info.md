# 009-where-things-are — info

The project root, the paths hanging off it, and the two rituals every program in this project observes: read input/ before doing anything, write output/ goodbye on the way out.

For a general: every program here needs to find its own files, and needs to agree with every other program about where they are. This is that agreement, written once. It also loads the settings file, which is where every tunable number in the project lives, so that no program carries its own copy of a number somebody is going to want to change.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `009-where-things-are.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.here()` | The directory this very file is sitting in, asked of the interpreter. |
| `M.canonical(path)` | One path, in the one spelling the filesystem agrees is where it is. |
| `M.root()` | The project root. Hard-coded, overridable, and checked against reality. |
| `M.set_root(path)` | Point the project somewhere else. What --dir does. |
| `M.path(...)` | Join fragments onto the project root. |
| `M.exists(path)` |  |
| `M.read_file(path)` | The whole file as a string, or nil and a reason. |
| `M.write_file(path, text)` | Written to a neighbouring temporary name and renamed into place. |
| `M.ensure_directory(path)` |  |
| `M.scratch(name)` | A path inside the RAM tier, with the whole symlink chain built if it is not |
| `M.load(name)` | Load a sibling source file by its indexed name, once. |
| `M.arguments(argv)` | The command line as a table. --key value, --flag, and bare words in order. |
| `M.settings()` | Every tunable number in the project, read from input/settings.lua. |
| `M.hello(program)` | The startup ritual: read input/, say what was found, hand back the settings. |
| `M.goodbye(program, lines)` | The last thing a program does: leave word in output/ of what it did. |

### `M.here()`

The directory this very file is sitting in, asked of the interpreter.

WHY THIS EXISTS. Twenty-odd source files need to load their siblings, and the alternative is the project root written into every one of them -- which is twenty-odd copies of a path that is wrong the moment the project moves. A file asking where it itself is cannot be wrong about it.

This answers "where is my sibling", which is a different question from "where is the project root". The root is DEFAULT_ROOT above, and the two are reconciled -- loudly -- in M.root().

The answer is made absolute before it leaves. The interpreter reports the path it was handed, so `luajit src/009-...` reports `src` -- a real answer to a different question, and one that makes the project root come out as the word "src". Every relative path is relative to where the shell was standing, so that is what gets prepended.

### `M.canonical(path)`

One path, in the one spelling the filesystem agrees is where it is.

Symlinks, bind mounts, `.`, `..` and doubled slashes all make a directory answer to more than one name, and anything that compares paths as strings is wrong in the presence of any of them. This project has exactly that situation on the machine it was written on -- the same directory is reachable under two different absolute paths -- so the comparison in M.root() had to be taught the difference between a different place and a different spelling.

### `M.root()`

The project root. Hard-coded, overridable, and checked against reality.

The check matters more than it looks. This file lives in <root>/src, so its own location states a root, and the constant at the top states another. When they disagree, somebody has moved or copied the project and the constant is stale.

Neither answer is silently preferred. Preferring the constant would make a moved copy read the original's data -- the worst possible outcome, because it works. Preferring the location would make the constant decorative. So: the location wins, because it is a fact rather than a claim, and the disagreement is announced once, because a fallback that nobody is told about is a fallback that becomes folklore.

### `M.write_file(path, text)`

Written to a neighbouring temporary name and renamed into place.

WHY THE RENAME. A run killed halfway leaves a half-written file that has the right name and the wrong contents, and everything downstream treats it as finished -- a truncated PNG renders as a broken image somebody spends an hour investigating. A rename within a directory is atomic, so a file either has all of its bytes or does not exist.

### `M.scratch(name)`

A path inside the RAM tier, with the whole symlink chain built if it is not

already there.

Two tiers, and they are different on purpose: /tmp/<project> is for anything executable and /dev/shm/<project> is for artifacts and logs. The project's tmp/ points at the first and tmp/shared-memory/ at the second. Everything this project writes at runtime is an artifact, so everything goes to the second one.

Rebuilt on demand rather than assumed, because both tiers are cleared by a reboot and the first program to run afterwards should not be the one that fails.

### `M.load(name)`

Load a sibling source file by its indexed name, once.

`require` is not used because these filenames carry their index and their hyphens -- 016-the-grey-canvas -- and those are the names the project reads itself by. Bending them into module identifiers would mean the file a person opens and the name a program uses are two different strings.

### `M.arguments(argv)`

The command line as a table. --key value, --flag, and bare words in order.

--dir is consumed here rather than by every program separately, because every program accepts it and none of them should have to remember to.

### `M.settings()`

Every tunable number in the project, read from input/settings.lua.

Read rather than defaulted. A program that carries its own copy of a blur radius is a program that ignores the one place a person went to change it, and the symptom of that is images that do not respond to the settings file.

### `M.hello(program)`

The startup ritual: read input/, say what was found, hand back the settings.

The first thing a program does is read the input directory. That is where it learns how to start up; nothing here decides anything for itself that the input directory could have decided. The files this project knows how to read out of input/. Anything else in there is something a person put there for a program to find, and naming it is how they learn whether any program saw it.

The list is here rather than absent because a notice that fires on every run is a notice nobody reads -- and one that fires on every run *of every worker in a batch* is worse than that, since it drowns the report.

### `M.goodbye(program, lines)`

The last thing a program does: leave word in output/ of what it did.

output/ is a mailbox, not a record. Whatever ran last is what is in there, and the next program overwrites it. It is for the person who walked away while something was running and wants to know how it went.

## Where it sits

Used by `010-fetch-the-archives`, `012-read-the-strokes`, `013-read-the-meanings`, `019-the-kanji-record`, `019a-a-phrase-is-a-record-too`, `020-test-the-ink`, `021-the-shape-of-a-stroke`, `022-the-structure-field`, `023-the-component-lexicon`, `024-the-scene-grammar`, `024a-the-paintbrush`, `025-the-words-the-machine-reads`, `026-arrows-that-teach-the-order`, `027-test-the-meaning`, `028-the-shape-of-a-graph`, `029-the-workflow-for-one-kanji`, `030-make-one-kanji`, `031-make-them-all`, `031a-when-the-machine-runs-hot`, `032-a-gallery-you-can-page`, `033-the-documentation-site`, `034-the-companion-pages`, `035-test-the-machine`, `044-run-the-pictures`, `045-the-pool-that-remembers`, `046-two-ways-of-saying-it-is-good`, `047-the-quality-dial`, `048-what-a-higher-tier-buys`.
