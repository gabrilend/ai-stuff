<!-- Made by Claude (Opus 5.5), 2026-10-10, from notes/vision, during project initialisation, as the datapath for heat; updated whenever an issue changes it. -->
# Datapath: heat

```
sources: emitters, store walls (all unreleased light ends here), tab motors,
         the controller
  → temperature readings, one per source (number, °C)
  → heat policy:
      warm  → fewer releases per second (dimmer, cooler)
      hot   → air pumps on
      hotter → heat fins flare up and out from the hair
      too hot → emitters stop; the panel shows nothing until cooled
```
