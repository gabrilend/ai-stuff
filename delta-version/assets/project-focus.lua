-- project-focus.lua - One hand-written sentence per project: what it is for.
--
-- The census builds the front page's Active Development table from what it
-- can count -- how busy each project has been, how many issues it has closed,
-- how many phases it has laid out -- but it cannot count what a project is
-- *for*. That sentence is written by a person and kept here, one per project,
-- so the table can be regenerated without losing it.
--
-- A project that climbs into the table without a sentence here stops the
-- census with its name, rather than shipping an empty cell. Add the sentence
-- and run it again. Sentences for projects that have fallen out of the table
-- are kept: they will likely climb back.
--
-- Keys are the project's path as the census lists it (`games/enheim-tome`,
-- not `enheim-tome`). Values are plain strings; a pipe character would break
-- the markdown table, so there are none.

return {
    ["hero-less-moba"] =
        "A lane-pushing game with the heroes, jungle, and item shop removed, to see what is still standing",
    ["neocities-modernization"] =
        "Poetry website with GPU-accelerated LLM similarity navigation",
    ["every-software-image-able"] =
        "A disk image carrying a model, the code that runs it, and an instruction to build every piece of software it can fit",
    ["six-sided-dice-layer-cake"] =
        "A blueprint set a materials engineer could build from, every dimension given or derived",
    ["my-own-custom-vtt"] =
        "A virtual tabletop: several people at different computers sharing one imaginary space",
    ["soren-ds"] =
        "A handheld operating system for the Anbernic RG DS, a dual-touchscreen ARM device",
    ["games/enheim-tome"] =
        "A strategy game over one painting of one city, played as an ordinary person living in it",
    ["jurassic-maze"] =
        "A maze of stacked stone at a fixed corner-on angle, with a simulation inside that nobody plays and nobody wins",
    ["kanji-learning-image-generator"] =
        "For each kanji, a recipe for a picture, where the picture is the kanji",
    ["gif-generator"] =
        "A particle simulation described in prose, encoded to .gif without an encoder library",
    ["supcom-derivative-clone"] =
        "A factory war on dunes where nothing is out of range",
    ["world-edit-to-execute"] =
        "Reads a Warcraft III map and plays it again in a new engine, scriptable in Lua, wearing whatever art its modders bring",
    ["scripts"] =
        "The shared workshop every project borrows from: the commit gate, the issue checker, the progress dashboard, the transcript keepers",
    ["words-pdf"] =
        "Poems laid out as pages, with artwork keyed to each poem",
}
