# Datapath: a round, and the campaign it moves

```
command act (028 table, or the mind headless)
   push direction (legal: on the map) + one perk card (+ "be one of them?")
        │ return
        ▼
begin_round (017): perk recorded; the enemy draws a perk and a push
   (weighted toward heading straight for the player's home: S, SW, SE)
   region = the neighbour of the front in the push direction
   battle (014) built in that region's ground, with its own streams
   (match seed × 1000 + round), every soldier fresh, perks applied (015);
   enemy push SW / SE deploys it toward a wing
        │
approach act (third person): volleys, shield wall
        │ any two enemies within engage range
        ▼
front_rank act: the person drops into first person (tab to leave or
   return); if the player's soldier falls, back to third person
        │ a side breaks (a quarter or fewer standing) or time runs out
        ▼
result act: totals added, history row written, campaign resolved (016):
   won  → that region becomes the player's, the front moves into it;
          won in the enemy's home → the match is won
   lost → the front region becomes the enemy's, the front steps back
          toward the player's home; lost at home → the match is lost
   draw → nothing moves
        │ after the result pause
        ▼
next command act
```

## The records

| Record | Fields |
| --- | --- |
| match | config, catalogue, seed, streams, person (boolean), map, round (integer), act (string), act_time (seconds), taken[team] (list of { name, be_affected }), choice { push, perk, be_affected }, cards (perk names), battle, result (false, 1, 2), player_in (boolean), history, totals, draws |
| map | width, height, regions (array of { col, row, kind, owner }), home[team] { col, row }, front { col, row }, result |
| history row | round, push, region, winner, seconds, standing { team 1, team 2 } |
