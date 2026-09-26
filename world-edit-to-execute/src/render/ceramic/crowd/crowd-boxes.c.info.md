# crowd-boxes.c

The crowd map's one box (issue 515k): `decide_chunk(chunk_req) ->
chunk_done`. `chunk_req`: `chunk`, `first`, `last` (ints: units first ..
last-1). `chunk_done`: `chunk`, `count`. The crowd travels by pointer
(`crowd_now`, set by the host; `crowd_dt`), as large read-only data does.
