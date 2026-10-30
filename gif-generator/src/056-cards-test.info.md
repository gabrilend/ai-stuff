# 056-cards-test — every film keeps its card

Films a few scenes with the film tool into a scratch folder and checks:
each film gets a card naming what made it and what moves in it; the
approved films start at five; a rating is one line added at the end and the
last counts; the viewer's own reader and writer (`viewer/rate.lua`) agree
with the maker's; a film made again with the same bytes leaves its card
alone, and with new bytes starts unrated with its old ratings kept; a film
made again into an approved one carries the approval; `--write` cards films
made before cards; the count reads the cards right.

CLI: `luajit src/056-cards-test.lua DIR`; `./test-shape-films` runs it.
