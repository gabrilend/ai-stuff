# Issue A11: A Feedback Box on Every Documentation Page

**Phase:** A - Infrastructure Tools
**Type:** Tool (shared page part, an rmail drop-off, the documentation builders)
**Priority:** Medium
**Status:** Open
**Dependencies:** A10 (pictures in the pages, built alongside); 035 (transcript-site); the rmail project (/mnt/mtwo/programs/r-mail)

---

## Why this exists

> We should make it part of the "HTML documentation builder" functionality
> we've built up. To make it always default. Alongside the
> "rmail-in-the-browser feedback box" which should go on every page where we
> describe something documentation style. less so on the artistic artifacts or
> the philosophy.

The house rule already asks for it: every documentation page that explains
mechanics or behaviour should let a reader type a message that lands in the
project's own rmail inbox, so feedback arrives where the work is.

## Current Behavior

No page has one yet. There is no shared documentation-site builder: projects
build their own (soren-ds `scripts/build-docs`, the kanji project's
documentation-site source), and transcript-site builds the story pages.

**The way a page reaches rmail is already built** (her answer: "check the
recent rmail issue files"): r-mail's `.claude/skills/rmail-integration/`
describes it, rmail issue #420 built it (2026-10-09), #714 builds on it. Each
website is one contact in the receiving mailbox with its own token and
`listen = true`, which lets it deliver a plain message and nothing else — no
edits, deletions, attachments, and nothing is ever sent to it. The page seals
each message itself in plain JavaScript (`rmail-seal.js`, which works on plain
http pages too) and posts the frame straight to the mailbox's port; rmail
unwraps the web post. So the box is safe for public visitors, not only for
her: the token in the page is treated as known to anyone, and the contact can
do no harm with it. A receive hook checks what arrives.

## Intended Behavior

1. **One page part, shared.** A small block of HTML and script any builder
   includes: a text box, the page it is on, a send button, and an honest
   status line (sent, or why not). Placed by default on documentation pages
   (issues, datapaths, info pages, progress, the story's contents); left off
   pages a builder marks as art or philosophy.
2. **Straight to the mailbox, the rmail-integration way.** One listen-only
   contact per site in the receiving mailbox; the page part loads
   `rmail-seal.js` (copied from r-mail, not rewritten) and calls
   `RMAIL_SEAL.sendMessage(mailbox_url, site_token, page_name, text)`. No
   separate listener is needed.
3. **Default in every builder.** transcript-site and the shared page head gain
   it; the project-init skill and the documentation guidance name it, so a new
   project's pages have it without anyone remembering.

## Suggested Implementation Steps

1. The page part: a box, the page's name as the subject, the honest status
   line, `rmail-seal.js` beside it; a page-kind switch (documentation / art).
2. transcript-site: a `feedback` setting (mailbox address and the site's
   token) and the box on the contents page and each conversation page.
3. The contact in the receiving mailbox, with `listen = true`, made by her.
4. One project's documentation builder as the first adopter; the guidance
   updated so the rest follow.

## Open Questions

1. Who will type into it: answered — the rmail method is safe for anyone.
2. Which inbox receives: her main mailbox with one contact per site, or a
   mailbox per project (r-mail's `scripts/install.sh` makes one)? And at what
   address and port can a visitor's browser reach it?
3. The site token is written into the page's script and so is public; it
   must be a token used for nothing else. She makes it in the mailbox's
   `contacts`, or asks for one to be made.
