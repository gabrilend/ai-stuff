#!/bin/bash
# run-net-tests.sh - runs every test of the gameplay messages, the server, the crowd, the matchmaking messages and the matchmaking server (issues 803, 804, 405f, 801a, 801b)
#
# In plain terms: checks the messages survive the trip to bytes and back,
# the server keeps its rules against a made-up game, the server on its
# own thread behaves through a clean and a troubled connection, and the
# matchmaking server keeps its lobbies, alone and as a daemon on a
# loopback of its own (unshare -rn).
#
# Usage: run-net-tests.sh [DIR]

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
failed=0
for t in test_net_messages test_net_messages_c test_net_server test_net_hosted test_crowd test_matchmaking_protocol test_matchmaking_server test_matchmaking_daemon; do
    echo "== ${t}"
    luajit "${DIR}/src/tests/${t}.lua" "${DIR}" | tail -1
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then failed=1; fi
done
if [ "${failed}" -ne 0 ]; then echo "net tests FAILED"; exit 1; fi
echo "net tests passed"
