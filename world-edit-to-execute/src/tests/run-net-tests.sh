#!/bin/bash
# run-net-tests.sh - runs every test of the gameplay messages, the server, the crowd, the matchmaking messages, server and client (issues 803, 804, 405f, 801a, 801b, 801c, 801d, 801e, 801f, 801g)
#
# In plain terms: checks the messages survive the trip to bytes and back,
# the server keeps its rules against a made-up game, the server on its
# own thread behaves through a clean and a troubled connection, and the
# matchmaking server keeps its lobbies and the client library sees them,
# alone and over a loopback of their own (unshare -rn), and NAT detection
# and hole punching, on simulated routers and on real UDP, and the
# lobby's countdown, kicks and multiplayer screens, the asset mirror's
# packs, and the server's command-line tool.
#
# Usage: run-net-tests.sh [DIR]

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
failed=0
for t in test_net_messages test_net_messages_c test_net_server test_net_hosted test_crowd test_matchmaking_protocol test_matchmaking_server test_matchmaking_daemon test_matchmaking_client test_matchmaking_client_net test_matchmaking_nat test_matchmaking_nat_net test_matchmaking_lobby_ui test_matchmaking_packs test_matchmaking_cli; do
    echo "== ${t}"
    luajit "${DIR}/src/tests/${t}.lua" "${DIR}" | tail -1
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then failed=1; fi
done
if [ "${failed}" -ne 0 ]; then echo "net tests FAILED"; exit 1; fi
echo "net tests passed"
