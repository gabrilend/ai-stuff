# pose-types.lua

Prints the value types `mat4`, `pose` and `chunk_pose` as C typedefs with
one named field per element (`m0`…`m15`, `b0`…`b29`, `u0`…`u63`). The
ceramic engine's value types can't hold number arrays. The builds splice the
output into `pose-boxes.c` at `/* @@POSE-TYPES@@ */`.
