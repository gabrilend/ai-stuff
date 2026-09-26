# run-mailbox-tests.sh

Builds `test-mailbox` twice (plain, and with ThreadSanitizer), then runs:
the real mailbox; the broken one, which must be caught by name; the real
one under the sanitizer with fewer states. Writes
`tmp/shared-memory/ceramic/mailbox-tests.txt`; exits 1 if any part fails.

- **Usage:** `run-mailbox-tests.sh [DIR]`.
