-- Part 9: 20 August through 1 September 2026.

return {

  part = 9,
  slug_name = "the-august-ledger",
  title = "The August Ledger",
  eyebrow = "Part 9 · 20 August – 1 September 2026",
  compiled = "compiled 1 Sep 2026, corrected 2 Sep",
  dek = "Nine projects at once. A maze generator is condemned by arithmetic about "
    .. "sight lines, a cube-shaped computer's eighty-four blueprints all agree for "
    .. "the first time, and 226 poems turn out to be reachable from nowhere on the "
    .. "site that indexes them.",

  totals = {
    { value = "548", label = "issues written" },
    { value = "281", label = "completed" },
    { value = "9", label = "projects" },
  },

  -- {{{ days
  days = {
    { label = "20", value = 1,  month = "August" },
    { label = "21", value = 24, emphasis = true },
    { label = "22", value = 6 },
    { label = "23", value = 1 },
    { label = "24", value = 8 },
    { label = "25", value = 33, emphasis = true },
    { label = "26", value = 82, emphasis = true },
    { label = "27", value = 11 },
    { label = "28", value = 25, emphasis = true },
    { label = "29", value = 0 },
    { label = "30", value = 0 },
    { label = "31", value = 28, emphasis = true },
    { label = "01", value = 10, emphasis = true, month = "September" },
  },
  chart_alt = "Commits per day from 20 August to 1 September 2026, peaking at 82 on "
    .. "the 26th, with the 29th and 30th silent.",
  chart_caption = "Commits per day. The 26th is one day in which most of the virtual "
    .. "tabletop, most of the cube blueprint set and most of the kanji study tool "
    .. "were committed.",
  -- }}}

  -- {{{ intro
  intro = {
    { kind = "lead", text = "The window runs 20 August to 1 September. A week of "
      .. "silence before it." },
    { kind = "p", text = "Nine projects, and unusually for this record they are nine "
      .. "different subjects rather than two or three. The largest single day is the "
      .. "26th, which carries 82 commits across three unrelated projects." },
    { kind = "thread", name = "Blueprints outnumber code", first = 1,
      text = "Two projects here write a great deal and finish none of it: the city "
        .. "game writes 106 issue files and completes zero, the lane-pushing game "
        .. "writes 99 and completes zero. **Between them that is 205 blueprints for "
        .. "work that has not started**, in a window where five other projects "
        .. "completed 281 issues between them." },
  },
  -- }}}

  work_caption = "Issue files, 20 August – 1 September",
  -- {{{ work
  work = {
    { name = "my-own-custom-vtt",              commits = 120, added = 96, removed = 0 },
    { name = "six-sided-dice-layer-cake",      commits = 110, added = 98, removed = 0 },
    { name = "games/enheim-tome",              commits = 106, added = 0,  removed = 0 },
    { name = "hero-less-moba",                 commits = 99,  added = 0,  removed = 0 },
    { name = "jurassic-maze",                  commits = 71,  added = 55, removed = 0 },
    { name = "kanji-learning-image-generator", commits = 40,  added = 32, removed = 0 },
    { name = "every-software-image-able",      commits = 2,   added = 0,  removed = 0 },
  },
  -- }}}
  work_note = {
    { kind = "p", text = "Columns are issue files written and completed. The poetry "
      .. "website and the shared tooling appear below without new issue files — "
      .. "their work this window is repairs to things already built." },
  },

  projects_caption = "What happened",
  projects = {

    -- {{{ jurassic-maze
    {
      id = "maze", name = "jurassic-maze", short = "jurassic-maze",
      commits = 71, slug = "71 issues written, 55 completed",
      identity = "The generator that had been building the world since the project "
        .. "started is deleted, because arithmetic showed most of the world could not "
        .. "be seen.",
      stats = {
        { key = "Of the maze hidden", value = "71", note = "%" },
        { key = "Broken links found", value = "109" },
        { key = "Spheres", value = "900" },
        { key = "A world is now", value = "2", note = "files" },
      },
      blocks = {
        { kind = "p", text = "A field of stacked stone blocks drawn from one fixed "
          .. "corner-on angle, so a square field reads on screen as a diamond. Tall "
          .. "stacks are walls, short ones are floors, and the corridors are the short "
          .. "places. Nothing inside a stack is ever represented: only exposed top "
          .. "surfaces and exposed side faces exist." },

        { kind = "pull", text = "Looking at the reference painting closely enough to "
          .. "count courses of masonry settles it: there is not one wall in the whole "
          .. "picture. Every vertical surface in it is the side of a higher flat "
          .. "plate, and what reads as a wall between two corridors is the edge of a "
          .. "block whose own top is walkable." },

        { kind = "p", text = "**What made that findable is that the visibility problem "
          .. "had been measured rather than argued about.** In this projection the "
          .. "line of sight climbs 1.6 stone layers per diagonal cell, and a wall "
          .. "standing two layers above its corridor is 2 — twenty pixels of wall "
          .. "against sixteen pixels of diagonal step, so the wall's top face is drawn "
          .. "over the floor behind it and that floor is gone. The generator laid rooms "
          .. "at odd coordinates, so the cell diagonally in front of every room was a "
          .. "lattice post, and a post is always a wall. **Every room in the maze was "
          .. "hidden by its own front post, on every random seed. Seventy-one percent "
          .. "of the maze could not be seen.**" },

        { kind = "p", text = "So the generator was deleted. The world is now a file "
          .. "somebody typed, describing a mountainside rather than a nested pyramid, "
          .. "with every shelf visible from summit to base — and nine hundred spheres "
          .. "roll down it bouncing off real geometry and off each other. Every "
          .. "collision defect had been invisible at three hundred balls and "
          .. "unmissable at nine hundred." },

        { kind = "p", text = "**A world then became two files**: a picture and a small "
          .. "data file. A position becomes a pixel through five numbers and there is "
          .. "nothing else to know, which is what makes the picture interchangeable — "
          .. "the one the exporter writes is a picture of this project's mountain, and "
          .. "a painting somebody made by hand does just as well. So the projection "
          .. "lives in the data file rather than being assumed by the program." },

        { kind = "p", text = "Deciding whether a body is hidden behind a rock is done "
          .. "without a depth buffer and is **exact rather than approximate**: cast "
          .. "one ray from the body toward the camera and ask whether any stack of "
          .. "stone stands over it. One ray per body per frame. The sightline work has "
          .. "now paid for itself three times — as the measurement that condemned the "
          .. "generator, as the check on the hand-authored map, and as the entire "
          .. "visibility model." },

        { kind = "thread", name = "Documentation drifts from the thing it describes", first = 5,
          text = "The documentation grew a build program that turns the plain-text "
            .. "documents into linked pages, plus a validator. **It found a hundred and "
            .. "nine broken links on its first run.** The lesson recorded alongside the "
            .. "pivot is sharper: six measurements had been taken off the reference "
            .. "picture, every one about a dimension — corridor width, wall height, "
            .. "stair run — and none about what the thing was *made of*, which turned "
            .. "out to be the only question that mattered." },

        { kind = "transcripts", project = "jurassic-maze", items = {
          { file = "aug-31-26-through-sep-1-26.md", label = "31 Aug – 1 Sep" },
          { file = "sep-1-26.md", label = "1 Sep" },
        } },
      },
    },
    -- }}}

    -- {{{ six-sided-dice
    {
      id = "cube", name = "six-sided-dice-layer-cake", short = "six-sided-dice-cake",
      commits = 110, slug = "110 issues written, 98 completed",
      identity = "Eighty-four engineering blueprints for a computer shaped like a "
        .. "cube, and a program that evaluates every derivation in them.",
      stats = {
        { key = "Blueprints", value = "84" },
        { key = "Symbols", value = "1,375" },
        { key = "Constraints", value = "532" },
        { key = "Failing", value = "0" },
        { key = "Check time", value = "<1", note = "s" },
      },
      blocks = {
        { kind = "p", text = "Every dimension is either chosen outright or written as "
          .. "an arithmetic expression over dimensions that were, and every rule the "
          .. "design must satisfy sits next to the part it constrains. Because the "
          .. "derivations are arithmetic rather than prose, a program evaluates all of "
          .. "them: **the whole cube can be resized by editing one file of eleven "
          .. "chosen lengths and rerunning the checker, which reports which rule "
          .. "breaks first.**" },

        { kind = "findings", items = {
          "**The cost model came out in a different order than the ticket "
            .. "predicted.** It expected silicon area first, then yield, then bonding. "
            .. "What came out is that **the memory tiers are two thirds of the silicon "
            .. "bill, not the compute dies** — a tier is forty millimetres square, "
            .. "large enough that only about two thirds come off a wafer intact, so a "
            .. "third are scrapped before assembly starts.",
          "**Assembly yield came out better than the raw arithmetic threatens, and "
            .. "the constraint was rewritten because of it.** About nine cubes in ten "
            .. "survive being built from known-good parts, and that is *because of* "
            .. "four mitigations already designed in: gates that test a part before "
            .. "committing it to an assembly, spare rows in each memory tier, one whole "
            .. "spare tier, and spare conductors between faces. So the constraint now "
            .. "asserts that yield stays **visible** in the report rather than that it "
            .. "is high — specifically so nobody reads a healthy figure and removes the "
            .. "mitigation that produced it.",
          "**One table claimed the cube had six opposite faces and nothing could "
            .. "tell.** A cube has three opposite pairs. That is what motivated "
            .. "teaching the checker this shape of mistake.",
          "**Twenty-seven unit conversions were happening silently** in the "
            .. "input-output face, and twelve material properties were being read that "
            .. "nobody had written into the materials table — four of which had no "
            .. "value anywhere.",
        } },

        { kind = "thread", name = "One owner for the shared thing", first = 4,
          text = "**A physical quantity must not be recognised by the identity of the "
            .. "table attached to it.** Two modules that each load the units engine "
            .. "independently end up with two copies of it in memory, and a quantity "
            .. "built by one copy is rejected by the other with a message saying it is "
            .. "not a quantity. Correct, baffling, and fixed by tagging each quantity "
            .. "with a marker field instead." },

        { kind = "transcripts", project = "six-sided-dice-layer-cake", items = {
          { file = "aug-26-26-through-aug-29-26.md", label = "26 Aug – 29 Aug" },
        } },
      },
    },
    -- }}}

    -- {{{ vtt
    {
      id = "vtt", name = "my-own-custom-vtt", short = "my-own-custom-vtt",
      commits = 120, slug = "120 issues written, 96 completed",
      identity = "Twelve phases finished, each with a runnable demonstration, most of "
        .. "them committed on 26 August.",
      stats = {
        { key = "Phases complete", value = "12", note = "of 13" },
        { key = "Demos", value = "12" },
        { key = "Creatures", value = "480" },
      },
      blocks = {
        { kind = "p", text = "Because a wall is a line segment rather than dark "
          .. "pixels, the program can compute what each person sees; because it can "
          .. "compute that, the darkness is per-person; and because the darkness is "
          .. "per-person, **the server can refuse to send you what you cannot see**. "
          .. "When a player cannot see around a corner, the bytes describing what is "
          .. "around it never leave the server. Not sent and hidden by the client: "
          .. "never sent." },

        { kind = "h", text = "Four questions asked after everything was finished" },

        { kind = "p", text = "Phase 12 exists only because four questions were put to "
          .. "the finished project, and every answer was a design the documents did "
          .. "not have." },
        { kind = "findings", items = {
          "**Owning a piece means the right to move it, not a fence around it.** "
            .. "Others can still affect a piece you own; they just cannot move it.",
          "**Nothing checks who you are.** Rather than pretend otherwise, the host was "
            .. "given the power to eject somebody and undo everything they did, and "
            .. "the documents say plainly that this is honest rather than secure.",
          "**A question with several plausible answers and no way to check any of "
            .. "them against the code is a question about a word that lies.** Asked "
            .. "what should end a turn's window, the answer came back as a question: "
            .. "*what do you mean by a window? Play runs continuously.* Nothing had "
            .. "ever waited. Three plausible answers had been written down and all "
            .. "three were about a thing that does not exist. Renaming the field "
            .. "dissolved two open questions at once.",
        } },

        { kind = "h", text = "A question about fog became a redesign" },

        { kind = "findings", items = {
          "**A cost problem can be a naming problem.** Tracing rays across terrain to "
            .. "the horizon came out four orders of magnitude over budget. Three "
            .. "structural fixes were found and costed — a hierarchy over the "
            .. "occluders, one over the targets, a precomputed shadow map — and none "
            .. "were needed, because nobody had asked whether the computer should "
            .. "decide visibility at all. Deciding it by hand when the map is authored "
            .. "**made the fast path unnecessary rather than achievable.**",
          "**A claim about a shrinking workload was wrong, and the correction was "
            .. "worth more than the claim.** Once a square is seen it stays seen, so "
            .. "the set left to test looked like it must shrink. It does not: in a "
            .. "world worth exploring the unseen stays nearly everything forever, and "
            .. "the squares you keep paying to test are the ones just around a corner. "
            .. "**The cost lives at the frontier** — small, local and moving, however "
            .. "large the world.",
        } },

        { kind = "transcripts", project = "my-own-custom-vtt", items = {
          { file = "aug-26-26-through-aug-27-26.md", label = "26 Aug – 27 Aug", untracked = true },
          { file = "aug-27-26-through-aug-29-26.md", label = "27 Aug – 29 Aug", untracked = true },
        } },
      },
    },
    -- }}}

    -- {{{ hero-less-moba
    {
      id = "moba", name = "hero-less-moba", short = "hero-less-moba",
      commits = 99, slug = "99 issues written, 0 completed",
      identity = "The soldiers get a second number beside their health, and it "
        .. "immediately raises a question that stops the rest of the work.",
      stats = {
        { key = "Phases built", value = "7", note = "of 9" },
        { key = "Issue files", value = "98" },
        { key = "Documents corrected", value = "60", note = "pages" },
      },
      blocks = {
        { kind = "p", text = "Two bases, three roads, stone towers, and an endless "
          .. "supply of identical soldiers walking at each other. Both sides emit the "
          .. "same thing at the same rate, so the line where they meet never moves and "
          .. "there is nothing a player can do — **because in the subtracted game "
          .. "there is nothing a player does.** The three replacement systems work at "
          .. "three speeds: a shared upgrade deck drawn when your team wipes a wave, a "
          .. "private wallet filled by every kill that buys single-use bodies, and "
          .. "three signposts per team that redirect where those bodies walk." },

        { kind = "p", text = "**Every body now carries terror beside its health, and "
          .. "retreats when terror plus remaining health drops below zero.** Because "
          .. "the sum uses *remaining* health, the same mouthful of despair a fresh "
          .. "body shrugs off breaks one that has been fought down — and a body just "
          .. "healed is braver than it was a second ago, without any healer needing a "
          .. "morale ability. Terror never kills: health at zero destroys a body, the "
          .. "same sum crossed by terror sends it home, one comparison decides which." },

        { kind = "pull", text = "An ordinary sword blow taking a body from three "
          .. "health to minus four puts the sum below zero with no terror involved. As "
          .. "written, damage sends bodies home and nothing in the game ever dies." },

        { kind = "p", text = "The reading that fits is that below zero means *beaten*, "
          .. "and what happens to a beaten body has been referred to in the documents "
          .. "for months without anywhere defining what being beaten is. Two halves of "
          .. "one rule, written apart, neither having had the other. It blocks the "
          .. "rest of the phase." },

        { kind = "findings", items = {
          "**Being pushed \"up\" was given a meaning that needs no third axis.** The "
            .. "map is flat, so *up* now means backwards along the path the body just "
            .. "walked. A body pushed that way has been *slowed* rather than "
            .. "deflected: it keeps its heading, its column and its place in the "
            .. "queue, and simply arrives later.",
          "**Every match anyone had ever watched was the same match.** The random "
            .. "number generator started from a fixed value, so every screenshot came "
            .. "from one identical run. The setup file now accepts *random*, draws a "
            .. "fresh value, and appends it to a notebook in memory — because a "
            .. "starting value nobody wrote down is a match nobody can replay.",
          "**A single rule can now be watched on an empty stage.** Bodies were "
            .. "bunching into a stationary column during the end-of-match siege, and "
            .. "finding out why meant playing a whole match and squinting at it. "
            .. "**Twice in one week a measurement taken off a whole match was blamed "
            .. "on the wrong thing.** There is now a way to stand up a short straight "
            .. "road with four bodies and nothing else running — and what the test did "
            .. "not ask for is *absent* rather than merely idle.",
        } },

        { kind = "thread", name = "One owner for the shared thing", first = 4,
          text = "The 173 browsable documentation pages stopped being committed, "
            .. "because a build program writes them from the prose beside them. "
            .. "Committing them means a one-line prose edit arrives as a change to "
            .. "itself plus a hundred and sixty files of machine output, **and two "
            .. "people who both ran the build get a conflict in a file neither of them "
            .. "wrote.**" },

        { kind = "transcripts", project = "hero-less-moba", items = {
          { file = "aug-24-26.md", label = "24 Aug", agents = 1 },
          { file = "aug-25-26-through-aug-26-26.md", label = "25 Aug – 26 Aug" },
          { file = "aug-26-26-through-aug-29-26.md", label = "26 Aug – 29 Aug" },
          { file = "aug-31-26-through-sep-1-26.md", label = "31 Aug – 1 Sep", untracked = true },
          { file = "sep-1-26-through-sep-2-26.md", label = "1 Sep – 2 Sep", untracked = true },
        } },
      },
    },
    -- }}}

    -- {{{ enheim-tome
    {
      id = "enheim", name = "games/enheim-tome", short = "enheim-tome",
      commits = 106, slug = "106 issues written, 0 completed",
      identity = "A whole layer of the design is deleted because its own text priced "
        .. "it at four years of typing.",
      stats = {
        { key = "Issue files", value = "94" },
        { key = "Built", value = "0" },
        { key = "Superseded", value = "6", note = "filed" },
      },
      blocks = {
        { kind = "pull", text = "The map is not the city. It is one person's model of "
          .. "the city." },
        { kind = "p", text = "A block drawn with no data on it is not empty — it is a "
          .. "block that person does not know about, and ignorance renders as bare "
          .. "painting. Dragging the clock to three in the afternoon does not travel "
          .. "there; it shows what they believe would be true then. So **the time is "
          .. "only ever now**, and nothing on screen needs marking as hypothetical "
          .. "because none of it was ever a live camera." },

        { kind = "p", text = "**The city is now cut up rather than filled in.** It "
          .. "starts as one undivided whole and gets subdivided, so coverage is always "
          .. "total and the remaining work is how finely it is divided rather than how "
          .. "much exists. The map editor also moved inside the game, so a map is "
          .. "something a player can make and hand to somebody else." },

        { kind = "p", text = "**And a whole layer was deleted.** It described small "
          .. "written secrets — a key in a box, a chest across the yard — one authored "
          .. "per city block before anyone plays, and one per house forever after. Its "
          .. "own text priced that at two to four years of typing before the game "
          .. "would work." },
        { kind = "pull", text = "A design that states a four-year cost about itself has "
          .. "already failed. The wording gave it away before the arithmetic did: it "
          .. "defined an event as an object sitting in a box, and then called the verb "
          .. "possession. You do not hold a party." },

        { kind = "findings", items = {
          "**Anything with a character and a status is the same kind of thing, so a "
            .. "room counts as one of the people in it.** Five people in a room makes "
            .. "the room a sixth voice, each carrying one share. That deletes a tunable "
            .. "and gets the right behaviour at every crowd size for free: an empty "
            .. "place is entirely itself, somebody alone at home is half the building, "
            .. "and a packed square is its crowd rather than its stones.",
          "**Influence flows from the closed to the open**, which is the opposite of "
            .. "the intuitive direction — *open* means open to being changed. Set that "
            .. "beside the existing rule that a person is closed while busy and open "
            .. "while at rest, and the sentence the documents call the entire design of "
            .. "places — *the building is stone, and cannot adjust, and that is what "
            .. "roots people* — stops being figurative. **The only hours anybody can "
            .. "change are the hours spent at home, inside something broadcasting at "
            .. "them that cannot be broadcast back at.** Nobody wrote that; it is two "
            .. "other rules touching.",
          "**The narrative half renders nothing back into the simulation.** A bad "
            .. "paragraph is only a bad paragraph, the same moment can be narrated "
            .. "twice without the city noticing, and the whole thing runs unattended "
            .. "for a thousand simulated days with no narrator at all. The one "
            .. "exception is sharp: *naming* a newly minted personality dimension is a "
            .. "real change, because a new name becomes a new way of looking at the "
            .. "map.",
        } },

        { kind = "thread", name = "Replaced designs are filed, not deleted", first = 2,
          text = "Six replaced tickets were filed under their own names, each marked "
            .. "with what replaced it and why. Ten new tickets for the simulation and "
            .. "twelve for the narrative half are **numbered above the retired ones, so "
            .. "two different designs never share a ticket number.**" },

        { kind = "transcripts", project = "games/enheim-tome", items = {
          { file = "aug-28-26-through-sep-1-26.md", label = "28 Aug – 1 Sep" },
          { file = "aug-29-26.md", label = "29 Aug" },
          { file = "sep-1-26-through-sep-2-26.md", label = "1 Sep – 2 Sep" },
        } },
      },
    },
    -- }}}

    -- {{{ kanji + neocities + scripts
    {
      id = "rest", name = "three more", short = "three more",
      commits = 40, slug = "40 issues written, 32 completed",
      identity = "A study tool built in two days, a poetry site's neighbour lists "
        .. "repaired, and two commit gates written after a collision.",
      blocks = {
        { kind = "h", text = "kanji-learning-image-generator" },
        { kind = "p", text = "Not a picture with a character drawn on it: a landscape "
          .. "whose light and dark fall exactly where the strokes fall. Up close it is "
          .. "a scene; at thumbnail size it is 木, and the tree was standing along the "
          .. "vertical stroke the whole time. **A learner meeting 休 is normally told "
          .. "a shape and a word with no bridge between them.** Here 休 is a person "
          .. "beside a tree, so the traveller *is* the left three strokes and the "
          .. "trunk *is* the vertical one — there is nothing to associate, because "
          .. "there are not two things any more." },
        { kind = "p", text = "Everything it generates is kept and never deleted, and "
          .. "each image gets two independent judgements: a program that blurs it down "
          .. "and measures whether the character is still legible, and a gallery a "
          .. "person rates in that can write ratings and nothing else. **How often the "
          .. "two agree is itself measured.** Findings from building it: the automatic "
          .. "grader was rewarding the exact failure it could not see, a rating was "
          .. "erasing the record of which character the image was for, and every "
          .. "measurement in the project was secretly tied to a 768-pixel frame." },

        { kind = "h", text = "neocities-modernization" },
        { kind = "pull", text = "One poem turned up in 526 neighbour lists, the busiest "
          .. "one percent took an eighth of every slot on the site, and 226 poems "
          .. "appeared in no list whatsoever. Not ranked low — absent, unreachable by "
          .. "anyone moving sideways through the collection." },
        { kind = "p", text = "About three quarters of every vector this model produces "
          .. "is a direction shared with all the others, so when two poems were "
          .. "compared that shared component did most of the talking. Subtracting it "
          .. "before comparing drops the unreachable count **from 226 to 12**." },
        { kind = "thread", name = "Fallbacks hide bugs", first = 2,
          text = "Four tools exist to check that the stored similarity scores match "
            .. "what you get if you recompute them. When the storage layout changed "
            .. "underneath them nobody moved them across, and nothing in the build "
            .. "calls them, so nothing ever failed — **they simply went quiet.** Run "
            .. "again, one looked poems up by position rather than by name, found "
            .. "nothing, and reported an accuracy averaged over an empty set. **A tool "
            .. "reporting confidently on nothing is worse than one that refuses to "
            .. "start.**" },

        { kind = "h", text = "scripts" },
        { kind = "p", text = "Several assistants work in this repository at once, and "
          .. "a commit with no paths on it does not commit the author's work — it "
          .. "commits whatever happens to be staged. **This had already happened: one "
          .. "session's commit message ended up attached to another session's files "
          .. "while its own work stayed uncommitted and unnoticed.** A commit must now "
          .. "name its paths." },
        { kind = "p", text = "Staging carefully does not help, which is the part worth "
          .. "recording: adding your own files and then committing with no paths "
          .. "leaves them sitting there for anybody else's next commit to carry away. "
          .. "**The first version of the check had exactly the bug it exists to "
          .. "catch** — it looked for named paths anywhere on the line, so an earlier "
          .. "staging command's paths satisfied it on behalf of the commit that "
          .. "followed." },
        { kind = "p", text = "Both gates are described in their own documentation as "
          .. "**honour systems with witnesses rather than locks**: the party they "
          .. "constrain can edit them, remove them, or grant themselves an exception. "
          .. "What they buy is that the careless form is not the one that happens by "
          .. "habit." },

        { kind = "transcripts", project = "kanji-learning-image-generator", items = {
          { file = "aug-26-26_agent-1.md", label = "26 Aug" },
          { file = "aug-26-26-through-aug-27-26.md", label = "26 Aug – 27 Aug", untracked = true },
        } },
      },
    },
    -- }}}

  },

  -- {{{ open
  open = {
    { project = "hero-less-moba", state = "Blocked", tone = "blocked",
      waiting = "Terror is the second number each body carries beside its health, and "
        .. "a body retreats when the two added together fall below zero. But an "
        .. "ordinary killing blow also puts that sum below zero, so as written nothing "
        .. "dies. Needs a definition of *beaten*. And a retreating body needs "
        .. "somewhere to go: the guardhouses tower guards would return to are named as "
        .. "a prerequisite and not built." },
    { project = "hero-less-moba", state = "Unproven", tone = "open",
      waiting = "Phase 8 is five-sixths unbuilt and holds the automated player that "
        .. "runs ten thousand matches — the only thing that can say whether the line "
        .. "where the two armies meet actually moves. **Nothing yet proves the "
        .. "project's premise.**" },
    { project = "games/enheim-tome", state = "Design only", tone = "open",
      waiting = "94 issue files, nothing built. Phase 8 has ten tickets, none "
        .. "started; phase 9's twelve were written on the window's last evening, so "
        .. "the narrative half has blueprints and no code." },
    { project = "my-own-custom-vtt", state = "Designed", tone = "open",
      waiting = "Phase 13 fully designed, nine tickets, none started." },
    { project = "jurassic-maze", state = "Awaiting hand", tone = "open",
      waiting = "The tracing table for turning a painting into a world is built and "
        .. "the reference painting has not been traced — a person's job rather than a "
        .. "program's. Half the dungeon mode is unbuilt." },
    { project = "kanji-learning-image-generator", state = "Untested", tone = "open",
      waiting = "One ticket open on where a text panel may appear. **The recipe format "
        .. "has never been fed to the image generator it was written for**, and the "
        .. "first submission will find everything at once." },
    { project = "neocities-modernization", state = "Expected", tone = "open",
      waiting = "The stored similarity scores predate the change to how vectors are "
        .. "prepared, so the checker's first honest look reports near-total "
        .. "disagreement. This is correct and it says so — but the store has not been "
        .. "rebuilt." },
  },
  -- }}}

  -- {{{ tree
  tree = {
    { kind = "p", text = "**This part went stale three hours after it was compiled.** "
      .. "It was written on the evening of 1 September and three more commits landed "
      .. "that day at 21:54, 22:07 and 22:22 — two of them the city game's narrative "
      .. "tickets, one a pair of working transcripts committed beside the work they "
      .. "produced. The figures now include them. **A part whose window reaches today "
      .. "can be overtaken by its own subject.**" },
    { kind = "thread", name = "The record is load-bearing", first = 6,
      text = "One of those three commits is itself a correction and says so: a "
        .. "transcript was held back from the commit it belonged to on a misreading of "
        .. "the rule, and by the time that was noticed the commit had been published "
        .. "and another session's work sat on top of it. **Rewriting somebody else's "
        .. "ground to tidy it up was judged more expensive than a late commit**, so "
        .. "the record carries the late commit and the reason." },
    { kind = "p", text = "At the time of compiling, 227 files were modified and "
      .. "uncommitted, 204 of them in the lane-pushing game — an in-progress session "
      .. "belonging to somebody else. Nothing here was committed, staged or altered." },
  },
  -- }}}
}
