<!-- written by Claude (Opus 5.5), 2026-10-11, for issue 011 (pictures and moving pictures): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 032-the-gif-tests.test

Decodes the GIF writer's files with a decoder written separately (frames large enough to fill and restart the compression table), checks every colour number read back equals the one written; single-colour and single-pixel frames; a table of at most 256; and ImageMagick, when installed, reading the same colours. Run by scripts/run-tests.
