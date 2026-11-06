# test_parser_coverage.lua

Tests the parser coverage report (issue A06): how stored files are grouped
into kinds and that every listed parser loads; a real test map
(`assets/DAoW-2.1.w3x`) read and counted; a filter to one kind; a parser
that raises, or returns nothing, counted as a failure with its message; a
map that won't open; the text, Markdown and JSON outputs; and the
command-line tool's exit codes.

Run: `luajit src/tests/test_parser_coverage.lua [DIR]`
