# Expectation of boons

What is expected to go well, written down before it does, so that when it does
it is recognised rather than assumed.

---

**The game will answer when asked.** `--verify` exists. It was not written for
this project and it does exactly what this project needs: it takes a file
somebody wrote and says whether it is a real orders file. The hardest part of
this work has a truth oracle sitting in it already, shipped years ago by
somebody who had no idea.

That is worth noticing rather than taking. Most undocumented formats do not
come with a validator.

**The event text is already written.** Every province in an orders file carries
its own history in the game's own voice, dated by season and year, going back
to the beginning. The narrative layer of this project does not have to invent
the past — it has to *find* it, which is a much easier and much more honest
job.

**The collection is large.** A hundred savegames, several game versions, mods
loaded and not, games from a first turn and games years deep. Any parser that
agrees with all of it has been tested harder than a fixture could test it.

**The names are good.** Peisandros, Cheiron, Lakedaimon, Sidon, Paeon, Imbrios,
Alastor, Elone, Paller, Pandion, Euaimon, Pleuron, Philia, Uranokles. The game
gave them those. A cast list is waiting in every save.

**Three machines is the right number for three roles**, and that is a
coincidence worth being grateful for rather than clever about.

**The measurement will keep correcting the guess.** It already did once, before
a line of project code was written: a record stride worked out by eye was three
bytes wrong, and a tool that counted found it in a second. Every time that
happens the project gets more trustworthy, and it will keep happening.

---

May the parser meet a file it does not understand and say so.

May the remembrancer find nothing, often, and be believed.

May a person who could not play, play.
