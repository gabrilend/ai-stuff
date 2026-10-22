# Open questions

Every question met while designing guide-feature, gathered in one place. A
question stays here, unanswered, until it is worked through with the owner.
The answer is then written into the document it changes, and the entry here
says where it went. The project is in progress, not finished, while any
question here is open.

Most valuable first.

## Open

1. **Which project do the voices draw their random context from, and how do
   its files reach the fg-sora machines?** The vision says "from the project
   directory". Candidates: this project; whichever project the owner is
   working on at the moment; a list of projects. Ways to carry the files:
   rmail attachments sent from kuvalu (slow, but uses the same channel and
   its encryption), a copy made over the network when a thinker starts, or a
   read-only network share. Changes `docs/datapath-thinker.md` step 2.
2. **Which C library do the fg-sora machines use, glibc or musl?** Checked by
   listing `/lib/ld-*` on each. It decides whether rmail's compiled parts and
   llama.cpp can be built on kuvalu and copied over, or must be built for
   musl. Phase 5 starts here.
3. **Which remote places should the voices be able to relay to, and may
   project files leave the house?** Possible targets: a llama.cpp server on
   kuvalu's GTX 1080 Ti (stays on the home network), other machines the owner
   runs, or a hosted service such as the Anthropic API (the page and the
   sampled project files then go to that company's servers). Where should
   keys and passwords for them be kept on the fg-sora machines?
4. **When a remote backend fails, should a voice ever use another backend?**
   The current design says no: the failure is counted and the voice tries the
   same backend next turn, so the page never quietly changes which model is
   speaking. The alternative is an ordered list written in the input file,
   with every switch shown on the page.
5. **Which box rule is the default: a fixed size, the smallest viewer, or
   one named viewer?** And what fixed size, if fixed? See
   `docs/display-box.md`.
6. **When the box shrinks, how should a voice's frame that no longer fits be
   shown until its next frame?** Current design: show only the rows that fit,
   mark the voice `over-box`, count the hidden rows. The alternative is to
   hide that voice's frame entirely until it writes one that fits.
7. **Characters or screen columns?** The box counts characters (UTF-8 code
   points). Some characters, Japanese for example, take two columns in a
   terminal. If the voices may write them, the fit checker must count
   display columns instead.
8. **Which port does the page server listen on, and should it be reachable
   from outside the home network?** The HTML page is "remote access", and the
   watch is often away from home wifi. Reaching kuvalu from outside means a
   router port forward or a VPN, and then the page server needs a password,
   because the page holds excerpts of project files.
9. **Should a new run of the page keeper start from the last page of the
   previous run?** Everything in `tmp/shared-memory/` is RAM and is gone after
   a reboot. Keeping the last page means writing it to disk on goodbye.
10. **The vision says "one page of a chatlog ... or many". When does a page
    end and a new one begin?** Current design: there is one page, forever
    rewritten, and the history folder keeps every version. Is "a new page"
    something else, such as a new topic, a new day, or the box filling up?
11. **Can the person watching write into the page too?** The vision says
    "each part of it can be edited". kuvalu could author a fourth part, the
    person's, through the page keeper. Nothing in the current design lets
    the viewer type.
12. **Which language model, and what size, on each fg-sora?** The
    risc-v-ollama notes suggest Llama 3.2 3B at Q4 as a baseline for these
    machines. How well each model respects the box is something the phase-4
    demo will measure.
13. **Building the Apple Watch app needs a Mac with Xcode, and installing it
    needs an iPhone paired to the watch.** Is there a Mac available? The
    Android app can be built on kuvalu with the Android command-line tools.
14. **Should the voices know which voice is which, and that they are three
    copies of a small model?** It changes the prompt's first lines and
    probably the character of the conversation.

## Answered

- Inbox port: 111213 is impossible; it is **1223**. In
  `docs/architecture.md`. (`notes/first-answers.md`)
- One shared page versus rmail's author-only edits: **hook scripts hand
  arrivals to a running Lua program that does the logic**. In
  `docs/architecture.md` and `docs/datapath-frame-to-page.md`.
- What listens on the fg-sora ports today: **nothing yet**. In
  `docs/roadmap.md`, phase 5.
- What the display module is: **a protocol first, then a Lua window,
  terminal view, HTML page, Android app and Apple Watch app**. In
  `docs/page-protocol.md` and `docs/datapath-viewers.md`.
- Screen sizes: **a display box in characters, with misfits returned to the
  model like compiler errors**. In `docs/display-box.md`.
- Remote processing: **the voices can relay to remote models**. In
  `docs/datapath-thinker.md`.
