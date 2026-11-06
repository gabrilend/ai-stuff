#!/usr/bin/env bash
# test-stethoscope.sh
#
# Checks the session-to-session mailbox: that a listener without a permit is
# refused, that a question nobody may hear is not sent, that a question and
# its answer travel whole and in order, that withdrawing the permit stops a
# listen in progress, and that a wait which runs out says so with its own exit
# status instead of pretending an answer came.
#
# It works in a throwaway mailbox under the RAM tier, never the real one, so
# running it grants no real permit.

DIR="${1:-/home/ritz/programming/ai-stuff/scripts}"
SCOPE="$DIR/stethoscope"
BOX="$(mktemp -d /dev/shm/test-stethoscope.XXXXXX)"
trap 'rm -rf "$BOX"' EXIT

passed=0
failed=0

# {{{ check()
check() {
  local description="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL: $description (expected '$expected', got '$actual')"
  fi
}
# }}}

# A listener with no permit is refused.
"$SCOPE" --dir "$BOX" listen ward --patience 1 > /dev/null 2>&1
check "listening without a permit is refused" 1 $?

# A question to a name nobody may listen as is not sent.
echo "hello" | "$SCOPE" --dir "$BOX" send ward > /dev/null 2>&1
check "asking an unpermitted name is refused" 1 $?
check "and nothing was queued" 0 "$(ls "$BOX/ward/inbox" 2>/dev/null | wc -l)"

"$SCOPE" --dir "$BOX" permit ward > /dev/null

# Two questions arrive in the order they were sent.
first=$(printf 'how do I handle this?\n{"a": 1}\n' | "$SCOPE" --dir "$BOX" send ward)
sleep 1
second=$(echo "and this one?" | "$SCOPE" --dir "$BOX" send ward)
heard=$("$SCOPE" --dir "$BOX" listen ward --patience 2)
check "the oldest question is heard first" 0 \
      "$(echo "$heard" | grep -c "question $second")"
check "the question's body arrives whole" 1 \
      "$(echo "$heard" | grep -c '{"a": 1}')"

# An answer reaches the asker.
echo "parse it as json" | "$SCOPE" --dir "$BOX" reply ward "$first" > /dev/null
answer=$("$SCOPE" --dir "$BOX" await ward "$first" --patience 2)
check "the answer arrives" "parse it as json" "$answer"

# Replying to a question never heard is refused.
echo "x" | "$SCOPE" --dir "$BOX" reply ward "$second" > /dev/null 2>&1
check "answering an unheard question is refused" 1 $?

# A wait that runs out exits 2, not 0.
"$SCOPE" --dir "$BOX" await ward "$second" --patience 1 > /dev/null 2>&1
check "an empty wait reports nothing arrived" 2 $?

# ask = send + await, end to end, with a listener answering in the background.
# The second question is still waiting; hear it first, so the ask's own
# question is the next one and two listeners never race for one file.
"$SCOPE" --dir "$BOX" listen ward --patience 2 > /dev/null 2>&1
(
  heard=$("$SCOPE" --dir "$BOX" listen ward --patience 5)
  id=$(echo "$heard" | sed -n '1p' | awk '{print $2}')
  echo "answered in the background" | "$SCOPE" --dir "$BOX" reply ward "$id" > /dev/null
) &
helper=$!
asked=$(echo "ping" | "$SCOPE" --dir "$BOX" ask ward --patience 6 | tail -n 1)
wait "$helper"
check "ask waits for and prints the answer" "answered in the background" "$asked"

# Withdrawing the permit ends a listen in progress.
( sleep 1; "$SCOPE" --dir "$BOX" stop ward > /dev/null ) &
"$SCOPE" --dir "$BOX" listen ward --patience 5 > /dev/null 2>&1
check "stop ends a listen in progress" 1 $?

echo "stethoscope: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
