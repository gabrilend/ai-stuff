# World Edit to Execute

A game engine that plays Warcraft III custom maps (`.w3x` / `.w3m`) the way an
emulator plays a ROM: it reads the map file and runs it, with community-made
art in place of Blizzard's.

- Vision: [notes/vision](notes/vision)
- Roadmap: [docs/roadmap.md](docs/roadmap.md)
- All documentation: [docs/table-of-contents.md](docs/table-of-contents.md)
- **Legal implications** (what the project does with Blizzard's games, and
  where the risk sits): [docs/legal-implications.md](docs/legal-implications.md)

## Building the third-party libraries

```bash
scripts/build-dependencies.sh
```

Compiles each library the project needs from source into `deps/`.
