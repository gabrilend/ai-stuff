# Strategem — exclude by place, not by kind

A borrowed rule list carries the *purpose it was written for*, and that purpose
may be the opposite of yours.

The shared `.gitignore` exists to keep bytes out of a git repository. So it lists
`*.mkv`, `*.mp4`, `*.o`, `*.log` — whole **file types**. We wanted to reuse it to
skip unimportant **directories** while browsing. Reused verbatim, it excluded
every video on the drive — the exact files the user most wanted to walk.

The fix was to keep the *directory* and *specific-name* patterns and drop the
pure `*.ext` *type* patterns. One `if line:match("^%*%.[^/]*$") then return nil`.

The pattern that generalizes: **when you adopt someone else's filter, separate
its mechanism from its intent.** The mechanism (glob matching) transfers; the
intent (what "unimportant" means) may not. Ask what the list was *for*, and keep
only the rows whose intent matches yours. Seen since in: adopting a linter config
(style intent vs. correctness intent), reusing a search index's stopword list,
inheriting cache-eviction rules.

Corollary already observed here: `.git` was *absent* from the gitignore (git
self-ignores it), so faithfully honoring the source under-excluded. A borrowed
list has holes exactly where the original tool filled them by other means.
