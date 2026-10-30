# 041-gif-decode-test — proof for the gif reader

Three witnesses check `040-gif-decode.lua`: a round trip through this
project's encoder (`004-gif.lua`), a gif built by hand byte by byte, and the
real gifs in a folder (an independent block walker,
`tests/shape-films/gif-facts.lua`, and ImageMagick for one frame).

CLI: `luajit src/041-gif-decode-test.lua <gif-generator dir> <gif folder> <scratch dir>`.
Run with the rest of the viewer's checks by `./test-gif-viewer`.
