-- stroke-fingerprints.lua - the stroke-only scores as they rendered
-- before panes existed.
--
-- What this is, generally: issue 701d promises that a score with only
-- strokes renders byte-identical to what it rendered before a second
-- space was added. These are the SHA-256 fingerprints of the GIFs the
-- scores in input/ made on 2026-10-30, at the commit before 701d
-- (cf2124d); 054-two-spaces-test.lua renders each again and compares.
--
-- Data format: score name (input/<name>.lua) -> 64 hexadecimal characters.
return {
    ["orbit"] = "9d832c22cc892cdb6ccc0bde77267e8ab103c74d69a264df2f4fa8e70d7edad8",
    ["showpiece"] = "988e4fe092caabb5fa2aebc1f9a254cab8c532f369df2a12d904e3eb437a6be7",
    ["two-clocks"] = "1f7494d6260a9c93b6887f0dca8e10bcc58d9ed7244751eef26d1ba4dcf65eeb",
    ["two-clocks-512"] = "7d304c20e7cdb51fd1ad3f662fe3393c3028576adb5f00ba66caeb947190cbb9",
}
