-- The map editor's settings (issue 913): copy this file to
-- editor-settings.lua (not committed: it names this machine's folders) or
-- name another file in $WETE_EDITOR_SETTINGS, and fill in where things
-- live here. It is read as data only. Every field may be left out; Test
-- Map says which one it needs when it gets there.
return {
    test_map = {
        -- W02's converter, run as: <these...> <map.w3x> <build folder>.
        -- Not built yet (W02); until it is, Test Map stops at this step.
        -- It may write <build folder>/server-stamp, a line naming what the
        -- server reads, so the server is started again only when that
        -- changes; without it every file of the build counts.
        convert = nil,
        convert_seconds = 600,
        build_dir = "tmp/test-map/build",          -- relative: under this project
        log_dir = "tmp/shared-memory/test-map",    -- the run's log, each program's output, the receipt

        -- the W client's scripts/run (or a program taking the same
        -- arguments), not the client binary: scripts/run adds the client's
        -- own --maps, --client, --settings, --world and --assets and passes
        -- --test-map, --receipt, --camera, --realm and --account (added by
        -- the editor after these) through unchanged (W client issue 1109).
        -- A failure inside scripts/run before the client starts (a failed
        -- build, no data) leaves no receipt, so it is reported as a crash.
        w_client = nil,                            -- e.g. { "/path/to/custom-client/scripts/run" }
        w_client_dir = nil,                        -- where it runs; the folder above scripts/ when unset

        -- the local AzerothCore's test account. The name may be here or in
        -- $W_CLIENT_ACCOUNT; the password is better kept in
        -- $W_CLIENT_PASSWORD than here. The editor never writes it down.
        account = nil,

        server = {
            host = "127.0.0.1",
            login_port = 3724,                     -- the authserver's
            start_seconds = 180,
            stop_seconds = 20,
            -- started in order, stopped in reverse; {build} in a command is
            -- the build folder (also WETE_TEST_MAP_BUILD in its environment)
            programs = {
                -- { name = "authserver", command = { "/path/to/azerothcore/env/dist/bin/authserver" },
                --   dir = "/path/to/azerothcore/env/dist/bin", port = 3724 },
                -- { name = "worldserver", command = { "/path/to/azerothcore/env/dist/bin/worldserver" },
                --   dir = "/path/to/azerothcore/env/dist/bin", port = 8085 },
            },
        },
    },
}
