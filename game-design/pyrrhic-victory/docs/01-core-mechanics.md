# Core Mechanics: The Timeline System

## The Central Paradox

In war, every soldier who falls is a timeline that ends. But what if you could reach back and pull them forward?

Pyrrhic Victory operates on a simple premise: **death creates information**. When a soldier dies, the player learns *why* they died - the gargoyle's trajectory, the skeleton's ambush point, the aboleth's beam pattern. Armed with this knowledge, subsequent runs can intervene.

---

## The Branching Model

### Notation
```
X = Death (timeline ends)
O = Fade (saved by future intervention, enters dormant state)
- = Active timeline
```

### Example Progression

**Run 1:** Player marches up the causeway. Dies to gargoyle strike.
```
Player 1: -----------X
```

**Run 2:** New soldier spawns. Player 1's ghost replays their final moments. Player 2 advances further before dying to skeleton horde.
```
Player 1: -----------X
Player 2: -----------------X
```

**Run 3:** Player 3 spots the incoming gargoyle and shoots it before it strikes Player 1's position. Player 1 *fades* - their death has been prevented, but they aren't under control yet.
```
Player 1: -----------O
Player 2: -----------------X
Player 3: -----------------------X
```

**Run 4:** Instead of spawning Player 4, the player resumes control of the now-alive Player 1, continuing from their fade point.
```
Player 1: -----------O----------------X
Player 2: -----------------X
Player 3: -----------------------X
```

---

## The Fade State

When a past soldier is saved from death, they don't simply continue - they **fade**.

### Visual Treatment
1. A brilliant flash of white light
2. The soldier's form becomes translucent, ghost-like
3. They continue their original actions on autopilot
4. Upon current player's death, control transfers to the faded soldier

### Mechanical Implications
- Faded soldiers follow their original patrol/advance pattern
- They can still die to new threats
- They provide cover fire and draw enemy attention
- Saving multiple soldiers creates an expanding squad

---

## The Cascade Effect

As runs accumulate, the battlefield fills with semi-autonomous allies:

```
Run 10:
Player 1:  ----O--------O----------------
Player 2:  --------O--------------------
Player 3:  --------O-------X
Player 4:  ------------O----------------
Player 5:  ----------------O-----------
Player 6:  ----X
Player 7:  --------------------O--------
Player 8:  ------------------------X
Player 9:  ----------------------------O
Player 10: -------------------------------->  [ACTIVE]
```

Each O represents a moment of intervention. Each X is a casualty that couldn't (or wasn't) prevented. The player moves through time, sculpting a squad from would-be corpses.

---

## Victory Conditions

### Pyrrhic Victory
Complete the objective with casualties. The game always allows this - push forward at cost.

### True Victory
Complete the objective with zero casualties. This requires:
- Perfect knowledge of all threats
- Precise timing of all interventions
- Coordinated squad positioning

### The Minimum Path
The game tracks the theoretical minimum casualties for each run. A counter displays:
```
CASUALTIES: 7
THEORETICAL MINIMUM: 2
```

This haunts the player. You *could* have saved five more.

---

## Enemy Behavior and Information

### The Recording
Upon death, players see a replay of their final moments from a third-person view. This reveals:
- The attack that killed them
- Enemy positions at time of death
- Potential intervention points

### Enemy Patterns
- **Gargoyles:** Dive bomb from above, predictable trajectories
- **Skeletons:** Rise from graves, shamble toward noise
- **Nether-bats:** Impale soldiers from behind
- **Festus (Aboleth):** Floating eye-monster, sweeps beams across the bridge

Each enemy type has learnable patterns. Death teaches.

---

## Philosophical Note

The title "Pyrrhic Victory" refers to a victory that inflicts such devastating toll on the victor that it is tantamount to defeat. King Pyrrhus, after defeating the Romans at Heraclea, reportedly said: *"If we are victorious in one more battle with the Romans, we shall be utterly ruined."*

This game asks: what if you could un-ruin yourself? What if every casualty was a choice, not a consequence? The weight shifts from *loss* to *responsibility*.

You didn't fail to save them.
You chose not to.
