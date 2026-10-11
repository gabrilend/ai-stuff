<!-- Made by Claude (Opus 5.5), 2026-10-10, from notes/vision, during project initialisation, to group the crown's functionality into phases. -->
# Roadmap

Phases are clusters of functionality, foundations first, not a calendar.
Each starts as software (a simulation in Lua that generates data, and a
separate viewer that draws it) and becomes hardware where the simulation says
it is worth building.

## Phase 0 — Tools
Instruments the other phases use, foundations beneath the crown itself.
First: a CAD viewer — STL, OBJ and glTF (the house format: structured JSON)
read into one shape record and drawn in a turnable LÖVE window — so the
crown's parts can be modelled in any CAD program and looked at here.
**Ends with:** the crown sketch written in every format, compared by size,
parts and round-trip accuracy, and photographed in the viewer.

## Phase 1 — The mask
Tabs, slots, and the picture their overlap lets through: a model of the tabs,
a planner that turns a picture into tab angles and open slots, and a measure
of how close the mask comes to the picture and how long the tabs take to get
there.
**Ends with:** pictures beside the masks planned for them, with the match
score and the tab travel time for each, and a scene change played out tab by
tab.

## Phase 2 — The stored light
The emitters, the index-matched light pipe, the mirrored store and its
rotating aperture: a photon budget from emitter to release, the store's
holding time, and brightness by release rate.
**Ends with:** a light budget drawn as a flow from emitter to panel, with
what is lost to heat at each step, and brightness against release rate.

## Phase 3 — The panel on its arm
Where the release lands: the curved panel, the arm's reach and turn, and how
the picture stretches and moves as they change; the safety rule that no
release fires without the panel in place.
**Ends with:** the picture on the curved panel at several reaches and turns,
and the count of releases withheld because the panel was out of place.

## Phase 4 — The inputs
Six dials, A and B, the pocket stick and the cuff, through one decision table
to the picture and the arm.
**Ends with:** a recorded run of inputs replayed, showing each decision, the
picture it chose, and the arm motion it caused.

## Phase 5 — The crown and its heat
The band, its colour, where each part sits; heat from every source, the
release-rate throttle, air pumps and flaring heat fins.
**Ends with:** temperature over time for a long session, with each response
(throttle, pumps, fins, stop) marked where it began.

## Phase 6 — The whole crown
Every phase working together on one simulated wearer.
**Ends with:** a scripted session — inputs, scene changes, heat — drawn as one
timeline, with the picture seen on the panel at each moment.
