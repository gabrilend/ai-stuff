-- The documentation as browsable pages: every document, every issue and every file's
-- notes, with a table of contents down the side and links from anywhere to anywhere.
--
-- The generator can be checked by a machine -- that it produced a page for every source
-- file, that nothing it wrote is left behind afterwards -- and the validator already
-- refuses a document pointing at a file that is not there. What cannot be checked that
-- way is whether the result is a thing somebody can read their way around, which is the
-- entire reason it exists.

return {
  covers = {"706"},

  name = "The documents, in a browser",

  caption = "Build the pages and open the index. Every document, every issue, every " ..
            "file's notes, one style, a table of contents on the left.",

  ground = "person",

  run = "./build-documentation && firefox docs/HTML/index.html",

  ask = {
    "Does every page have the table of contents, and does it look like the same project " ..
      "on all of them?",
    "Pick an issue number mentioned in some other document and click it -- does it take " ..
      "you to that issue?",
    "From a file's notes, can you reach the issue that asked for that file?",
    "Is the code on the pages syntax-highlighted and readable?",
    "Is there any page you cannot get to from the index?",
  },
}
