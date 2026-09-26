#!/usr/bin/env luajit
-- crowd-gen.lua - writes the crowd's tick as a ceramic map (issue 515k)
--
-- In plain terms: the crowd's deciding, drawn as the engine reads it. It is
-- one station: every chunk of units the host hands in is a task of its own,
-- and the engine's workers take them as they come, however long each runs
-- (a chunk whose units re-plan can take a hundred times as long as one
-- whose units only step). The snapshot before and the settling after stay
-- with the host: they are one thread's work by design.
--
-- Doors (marked ports), which crowd-host.c relies on:
--   argument 0   the chunks to decide (chunk_req)
--   result 0     the chunks decided (chunk_done)
--
-- Usage: luajit crowd-gen.lua > crowd.map

print([[# The crowd's deciding (issue 515k), written by crowd-gen.lua.

station decide (crowd-boxes.c:decide_chunk)
  in 0 - 0$
  out 0 - 0$]])
