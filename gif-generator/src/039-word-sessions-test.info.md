# 039-word-sessions-test — proof for the word sessions and tracker

`luajit src/039-word-sessions-test.lua [DIR]`. Builds a scratch project in
RAM (a git repository with the format document, the example words and a
tracker in `issues/completed/`) and a stand-in `claude` in the exec tier
(`tmp/`, because `/dev/shm` is mounted noexec). Three words at once: two
taught, one broken file refused with its reason; the tracker moved back out
of `completed/` (git sees the rename), reopened, and given both rows in one
write. Re-runs itself with `SAY_CLAUDE` set.
