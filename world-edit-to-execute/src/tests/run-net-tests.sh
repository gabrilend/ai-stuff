#!/bin/bash
# run-net-tests.sh - runs every test of the gameplay messages, the server and the crowd (issues 803, 804, 405f)
#
# In plain terms: checks the messages survive the trip to bytes and back,
# the server keeps its rules against a made-up game, and the server on its
# own thread behaves through a clean and a troubled connection.
#
# Usage: run-net-tests.sh [DIR]

DIR="/mnt/mtwo/programming/ai-stuff/world-edit-to-execute"
if [ -n "$1" ]; then DIR="$1"; fi
failed=0
for t in test_net_messages test_net_messages_c test_net_server test_net_hosted test_crowd; do
    echo "== ${t}"
    luajit "${DIR}/src/tests/${t}.lua" "${DIR}" | tail -1
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then failed=1; fi
done
if [ "${failed}" -ne 0 ]; then echo "net tests FAILED"; exit 1; fi
echo "net tests passed"
