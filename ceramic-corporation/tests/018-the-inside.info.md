# 018-the-inside

Covers issue 201.

- The workshop's making box lines up with its inside, and the board, under
  making's row, names cutting as what the inside waits on first.
- One refusal per rule: an invalid inner org (N1), an in and an out port of one
  name (N2), an in port with no outside, no door in, or a door out to it (N3),
  the same for an out port (N4), an inner outside that is not a port of the box
  (N5), a map inside itself and a map inside a map inside it (N6).
- Two levels: both line up, the board looks inside a source and inside the
  source it finds there, and a problem two levels down is found from the top.
- `./validate-org` refuses an org whose inside does not line up.
