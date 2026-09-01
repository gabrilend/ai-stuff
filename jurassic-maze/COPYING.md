# Copying

**jurassic-maze is licensed under the GNU Affero General Public License,
version 3 or (at your option) any later version.**

    SPDX-License-Identifier: AGPL-3.0-or-later

The full text is in [LICENSE](LICENSE), reproduced verbatim from the Free
Software Foundation. It has not been edited, and it should not be.

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

Section 13 is the reason for this license rather than a permissive one. A
simulation that people watch is exactly the kind of thing that ends up behind a
web page, and a web page is exactly the arrangement under which the plain GPL
asks for nothing.

## Applying the notice to source files

Nobody types the notice. Two scripts handle it, and they are the only sanctioned
way a source file comes into existence or has its body replaced:

    ./new-source-file  <name>            claims the next index, stamps the notice,
                                         writes the companion .info.md stub
    ./fill-source-file <path> < body     replaces everything below the notice and
                                         refuses outright if the notice is absent

The notice text lives in exactly one place — inside `new-source-file` — so there
is one copy in the project to keep current. That is the entire argument for those
scripts existing.

## The one thing here that is not ours

`inspiration/inspiration-maze.png` is a reference image and is **not** covered by
this license. See [inspiration/NOTICE.md](inspiration/NOTICE.md) before doing
anything with it. No code in this project reads that directory.
