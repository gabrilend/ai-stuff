In wowchat custom class we accept LUA style syntax 

We should also accept a "rules and conditions" style input like trigger editor in wc3. There should also be an "effects" section that happens when an event with conditions applies.

This could enable things like "when your consecration expires it casts prayer of healing" or "hunters mark also applies curse of weakness" or something. Make the system very limited, and parse the input rather than execute it directly. Essentially, another interpreter layer that turns untrustable user code into valid byte code that can be executed by the server / AIO addon.

scripts.events["consc-healing"] = player.casts("consecration")

scripts.actions["consc-healing"] = instant("prayer of healing", player)

Or 

scripts.events["weaken-mark"] = player.casts("hunter's mark")

scripts.actions["weaken-mark"] = cast("curse of weakness", target)

Something that only applies to that class, but which runs on it's abilities. Allows for customization of spells. Parsed from files upon server reboot, cached for during gameplay.

Also unrelated, but what if bots moved toward groups of people they could see, and if they couldn't see any they moved to the top of a hill?

When they walk to a person, they then pick the farthest person away (within range) who they can walk to. Then repeat. If they don't see anyone besides the people nearby, then they go on an orbit path to a new random nearby person every so often, the orbit radius grows progressively bigger, until they are too far away. Hmmmm that might break it.

What if we just made bots walk between each NPC spawnpoint and touch all of them once, travelling salesman style? Fighting monsters as they go... Maybe three or more styles of adventuring? Do we ever send bots out gathering? We should 3x the resource quantity, and add more sinks that take in resources and output combat potential. Let us arm the wandering warriors! Trade to playerbots? And mercenaries for hire... To follow and join the party of someone you point to. Workflow is like this: invite 2 bots to party, then point at another nearby bot - your party members join a party with them, and treat them as if they were a player until they grow bored (happens sometimes)