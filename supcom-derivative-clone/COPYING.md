# Copying

**supcom-derivative-clone is licensed under the GNU Affero General Public
License, version 3 or (at your option) any later version.**

    SPDX-License-Identifier: AGPL-3.0-or-later

The full text is in [LICENSE](LICENSE), fetched verbatim from
<https://www.gnu.org/licenses/agpl-3.0.txt>. It has not been edited, and it
should not be.

## What the AGPL asks of you, in short

This is a summary for orientation and it is not the license. Where this page and
`LICENSE` disagree, `LICENSE` is correct.

- You may run, read, modify, and share this, commercially or not.
- If you distribute it, or a modified version, you pass on the same freedoms and
  the source.
- **And if you run a modified version where people interact with it over a
  network, the people using it over that network must be offered the source
  too.** That is section 13, and it is the difference between the AGPL and the
  plain GPL.

That last clause is the one that matters for this project, because this is a game
that people play against each other over a radio and over a wire. Anyone running a
modified version that other people join owes those people the modifications.

## Applying the notice to source files

Every source file this project adds carries the notice, near the top, in that
file's comment syntax. For Lua:

    -- supcom-derivative-clone — a factory war on dunes where nothing is out of range
    -- Copyright (C) 2026 gabrilend
    --
    -- This program is free software: you can redistribute it and/or modify it
    -- under the terms of the GNU Affero General Public License as published by
    -- the Free Software Foundation, either version 3 of the License, or (at
    -- your option) any later version.
    --
    -- This program is distributed in the hope that it will be useful, but
    -- WITHOUT ANY WARRANTY; without even the implied warranty of
    -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero
    -- General Public License for more details.
    --
    -- You should have received a copy of the GNU Affero General Public License
    -- along with this program. If not, see <https://www.gnu.org/licenses/>.
    --
    -- SPDX-License-Identifier: AGPL-3.0-or-later

**The file-creation tooling adds it**, rather than anybody typing it. `./new-source-file`
stamps the notice and claims the file's index in one motion; `./fill-source-file`
rewrites a body without ever disturbing the notice. No person in this project
handles a licence header, because a hand-copied header is the kind of boilerplate
that silently rots.

## What this covers

Everything in the repository: the simulation, the viewers, the tools, the
documents, the issue files, and the tests. The documents and issues are not
incidental to this project — they are how it is built, and reconstructing the
software means reading them. They are licensed with it.

## Work in this repository that is not mine

Third-party code arrives in `libs/` through `./install-dependencies` and carries
its own licence. Nothing this project does changes those terms; the manifest in
`input/dependencies` names where each thing came from. The monorepo's own
`COPYRIGHT` file, one directory up, explains the rule for finding the licence that
applies to any file: walk up from what you are holding until you meet one.

## The vision file

`notes/vision` is the author's own writing and the origin of everything else
here. It is covered by the same licence as the rest of the repository.
