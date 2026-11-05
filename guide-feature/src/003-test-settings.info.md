# 003-test-settings — info

Tests for `001-settings.lua`: a good file read into every type, the RAM tiers
made, a second read seeing an edit, one refusal for each way a file can be
wrong (each checked for its file and line), and the endpoints file good and
bad. Runs on a throwaway project under the system's temporary folder, with
the tiers' roots moved there (`EXEC_TIER_ROOT`, `ARTIFACT_TIER_ROOT`), so
nothing of the real project is touched. Needs LuaJIT (for `setenv`) and jq
(for the tiers library).

    luajit src/003-test-settings.lua [--dir ROOT]
