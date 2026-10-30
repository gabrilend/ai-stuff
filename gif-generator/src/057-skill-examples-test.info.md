# 057-skill-examples-test — the studio skill says only what the studio does

The skill an assistant loads to make pictures here lives beside this
project, at `../skills/gif-studio/SKILL.md` in the ai-stuff repository
(issue 701f). Its examples are fenced blocks labelled with what they are:

    ```lua score     a score: must pass the wall and film
    ```lua scene     a shape scene: must film through 039-shape-films.lua
    ```lua refused   a score the wall refuses; the ```text block right
                     after it is the refusal, word for word

This films every one, and checks that every project file the skill names
in backticks (`src/...`, `docs/...`, `tests/...`, `input/...`; a name in
capitals like `input/NAME.lua` is a placeholder) and every `./tool` exists.
A change to the language that the skill doesn't follow fails here.

CLI: `luajit src/057-skill-examples-test.lua DIR [SKILL]`;
`./test-shape-films` runs it.
