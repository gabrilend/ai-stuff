# msgpack.lua

MessagePack, the part the matchmaking messages use (issue 801a): nil,
booleans, whole numbers exactly up to 2^53 either way, other numbers as
64-bit floats, strings, lists and maps. A table whose keys are exactly
1..n is a list; any other is a map, its keys written sorted, so the same
table always gives the same bytes. No library to install.

- **`msgpack.encode(value) -> bytes`**: refuses a function, a table inside
  itself, a non-finite number, a map key that is not a string or number,
  or nesting deeper than `msgpack.MAX_DEPTH` (32).
- **`msgpack.decode(bytes) -> value`**: one value from all the bytes;
  refuses bytes cut short or left over, an extension type, a whole number
  past 2^53, a map key that is not a string or number, and nesting deeper
  than 32. "bin" is read as a string, a 32-bit float as the float it is.
