# 004-test-goodbye — info

Tests for `002-goodbye.lua`: a run started, counted, logged and finished; the
receipt read back line by line; the next run moving it aside; two receipts
compared with `diff`; a crashing program (a separate LuaJIT process) leaving
no receipt and a log with no end; and the names and numbers a receipt
refuses. Runs on a throwaway project, as `003` does.

    luajit src/004-test-goodbye.lua [--dir ROOT]
