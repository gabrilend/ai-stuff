# The Adventurer's Quest Log

```
+======================================================================+
|                                                                      |
|   :dagger:  {{PROJECT_NAME}} - QUEST BOARD  :dagger:                              |
|                                                                      |
|   "{{MOTTO}}"                                                        |
|                                                                      |
|   Quests sorted by difficulty. Complete them in order to             |
|   level up your understanding of the codebase.                       |
|                                                                      |
+======================================================================+
```

---

## Your Adventure Begins

Welcome, brave adventurer. Before you stand against the Boss Monsters
documented in the Bounty Hall, you must hone your skills on lesser creatures.

Each quest teaches you something about the codebase. Complete them in order.
By the time you reach the bosses, you'll have the weapons you need.

---

## Quest Tier: :seedling: Seedling (Trivial Fixes)

<!-- QUEST_TIER_SEEDLING -->
{{SEEDLING_QUESTS}}
<!-- /QUEST_TIER_SEEDLING -->

---

## Quest Tier: :herb: Apprentice (Simple Fixes)

<!-- QUEST_TIER_APPRENTICE -->
{{APPRENTICE_QUESTS}}
<!-- /QUEST_TIER_APPRENTICE -->

---

## Quest Tier: :crossed_swords: Journeyman (Moderate Fixes)

<!-- QUEST_TIER_JOURNEYMAN -->
{{JOURNEYMAN_QUESTS}}
<!-- /QUEST_TIER_JOURNEYMAN -->

---

## Quest Tier: :european_castle: Veteran (Complex Fixes)

<!-- QUEST_TIER_VETERAN -->
{{VETERAN_QUESTS}}
<!-- /QUEST_TIER_VETERAN -->

---

## The Boss Bounties

*When you have completed the Veteran quests, you are ready.*

| Bounty | Monster | Threat |
|--------|---------|--------|
{{BOUNTY_TABLE}}

---

## Progression Path

```
:seedling: Seedling Quests ({{SEEDLING_IDS}})
      |
      v
:herb: Apprentice Quests ({{APPRENTICE_IDS}})
      |
      v
:crossed_swords: Journeyman Quests ({{JOURNEYMAN_IDS}})
      |
      v
:european_castle: Veteran Quest ({{VETERAN_IDS}})
      |
      v
:dragon: Boss Bounties ({{BOUNTY_IDS}})
```

---

## Adventurer's Equipment

As you complete quests, you gain tools:

| Quest | Tool Gained |
|-------|-------------|
{{EQUIPMENT_TABLE}}

---

## Quest Completion Protocol

When completing a quest:

1. Create a branch: `quest/{{QUEST_ID}}-{{quest-name}}`
2. Write the fix
3. Add tests proving the fix
4. Update this log with completion notes
5. Submit for review

---

**Quest Board Maintained By:** {{MAINTAINER}}
**Last Updated:** {{DATE}}
