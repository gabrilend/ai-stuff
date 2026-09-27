# 056-the-update-commands.lua

Command rows `update <case> [--go]` (handle waiting requests; held ones go
into the goodbye's waiting list with the command that releases them) and
`grade <case> <request>` (locate and grade one request, record the grade,
print `output/<request>.grade`; nothing else changes).
