# Balance Updates

Append-only log of balance tweaks and number adjustments.

---

## 2026-03-17: Spawn Rate Slowdown

**Rationale:** Initial spawn rates were too fast, making the game feel rushed from the start. Slower initial rates give players time to observe ball physics and make upgrades feel more impactful.

**Changes:**

| Variable | File | Old Value | New Value |
|----------|------|-----------|-----------|
| SPAWN_RATE | 006-ball.h | 5.0f | 1.7f |
| ADVERSARY_SPAWN_RATE | 012-adversary.h | 4.0f | 1.3f |
| SPAWN_RATE_BONUS_PER_LEVEL | 011-upgrades.c | 0.01f | 0.0166f |

**Effect:**
- Player initial: 5.0 → 1.7 balls/sec (34% of original)
- Player max (500 upgrades): 10.0 → 10.0 balls/sec (unchanged)
- Adversary: 4.0 → 1.3 balls/sec (32.5% of original)

Upgrade description updated from "+5 ball/sec max" to "+8 ball/sec max".

---

## 2026-03-17: Low-Speed Impact Damage Threshold

**Rationale:** Gentle bumps between balls were dealing damage proportional to speed. Even slow 50 px/sec collisions dealt 5 damage, causing balls to die from insignificant contact. Balls should only take damage from meaningful collisions.

**Changes:**

| Variable | File | Old Value | New Value |
|----------|------|-----------|-----------|
| DAMAGE_VELOCITY_SCALE | 006-ball.h | 0.1f | 0.15f |
| DAMAGE_SPEED_THRESHOLD | 006-ball.h | (new) | 80.0f |

**Effect (damage per collision):**

| Closing Speed | Before | After |
|---------------|--------|-------|
| 50 px/sec | 5 | 0 (below threshold) |
| 100 px/sec | 10 | 3 |
| 200 px/sec | 20 | 18 |
| 400 px/sec | 40 | 48 |

Hard hits now deal more damage than before, but gentle bumps are harmless. Balls survive longer in crowded situations but still die from meaningful collisions.

---

## 2026-03-18: Gravity Assist Terminal Velocity Cap

**Rationale:** Balls sliding on lines could accelerate indefinitely as the gravity assist was applied every frame. This caused balls to reach unrealistic speeds on long diagonal lines.

**Changes:**

| Variable | File | Old Value | New Value |
|----------|------|-----------|-----------|
| TERMINAL_VELOCITY | 006-ball.h | (new) | 500.0f |

**Effect:**
- Gravity assist (30 px/sec boost) only applies when ball speed < 500 px/sec
- Balls on lines naturally cap at a reasonable speed
- Fast-moving balls (from falls or bounces) don't get additional acceleration

---

## 2026-03-18: Ball Durability and System Capacity Increases

**Rationale:** Balls were dying too quickly from accumulated collision damage, especially in crowded situations. System capacities were also too low for larger boards and intense gameplay.

**Changes:**

| Variable | File | Old Value | New Value |
|----------|------|-----------|-----------|
| BALL_MAX_HEALTH | 006-ball.h | 100.0f | 200.0f |
| MAX_BALLS | 006-ball.h | 256 | 1024 |
| particle capacity | 001-main.c | 256 | 1024 |

**Effect:**
- Balls now survive twice as many collisions before dying
- System can support 4x more balls simultaneously (up to 1024)
- Particle effects capacity increased to match ball capacity
