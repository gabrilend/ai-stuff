# Copying

**hero-less-moba is licensed under the GNU Affero General Public License,
version 3 or (at your option) any later version.**

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
that people play against each other over a network. Anyone running a modified
server owes its players the modifications.

## Applying the notice to source files

Every source file this project adds should carry the notice, near the top, in
that file's comment syntax. For Lua:

    -- hero-less-moba — a lane-pushing game with the heroes subtracted out
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

There is no source code yet, so no file carries it yet. **The file-creation
tooling should add it**, rather than anybody typing it — this project's standing
rule is to build the tool that makes the thing rather than making the thing by
hand, and a licence header is exactly the sort of boilerplate that rots when it
is hand-copied.

## What this covers

Everything in the repository: the simulation, the viewer, the tools, the
documents, and the issue files. The documents and issues are not incidental to
this project — they are how it is built, and reconstructing the software means
reading them. They are licensed with it.

## The vision file

`notes/vision` is the author's own writing and the origin of everything else
here. It is covered by the same licence as the rest of the repository.
