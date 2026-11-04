# libs/guide-trail.lua — info

A guide's record of a reader's walk, written only encrypted into its room
(issue 065f). Uses `guide-room.lua` and `guide-cipher.lua`.

| | |
|---|---|
| `M.open(room_dir)` | `{ room, key }`; makes the key on first use |
| `M.key_for(room)` | the key from `guide.key` in the room; made (owner-only, mode 600, set before the key is written) and listed as kept if absent |
| `M.note(trail, walk_id, text)` | appends one encrypted note (hex, one per line) to `trail-<walk_id>.trail`; first note lists the file as kept, later ones are dated as extensions |
| `M.read(trail, walk_id)` | the walk's notes, decrypted, in order (list of strings) |

A walk id is letters, digits and dashes.
