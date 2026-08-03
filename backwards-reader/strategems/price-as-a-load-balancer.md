# strategem — price as a load balancer

## The shape

A dispatcher with N places to send work needs a rule for choosing. The
usual rules are round-robin (ignores that doors differ), least-connections
(ignores that doors differ in speed), and hand-tuned weights (goes stale
the moment a machine changes).

Give every door a **price** instead. The price is a number the door quotes
for taking one more piece of work, and it is computed from what the door
can see about itself:

    price = observed cost per unit  ×  (1 + how much is already waiting)

Send each piece to the cheapest door. That is the whole rule.

## Why it behaves

- A fast door is cheap, so it gets work, so its queue grows, so it gets
  more expensive, so the others start winning. The queue term is the
  negative feedback; without it the fastest door takes everything and the
  cluster is one machine.
- A door that slows down — thermal throttle, someone else's job landed on
  it, the network got worse — gets expensive without anyone being told, and
  quietly stops receiving work. No health check, no timeout tuning. The
  price already said it.
- A door that dies is infinitely expensive and is simply never chosen. Death
  is the limit case of being slow, so it needs no separate code path.
- **Running the work here** is just another door with a price. The moment
  local execution is cheaper than the cheapest remote door, the dispatcher
  keeps the work — and that decision, made per piece, *is* the crossover
  point. It stops being a constant somebody tuned and becomes a thing that
  is measured continuously and never goes stale.

Prices equalize pressure. That is the property being bought, and it is why
the rule survives machines being added, removed, or changed underneath it.

## The catch

The price must be built from *measured* cost, not declared cost. A door
that says it is fast and is not will hoard work forever. Every door's price
must decay toward what that door has actually been observed to do, which
means the dispatcher has to keep timings per door and let them age. A
declared price is a promise; an observed price is a fact.

## Where else

This is the person's own note about the megacluster, written small. Pass it
along, be paid; process it, give away; tune the prices to equalize the
pressure. A cluster of three in a house is the same mechanism as a planet
of raspberry pis — only the number of doors differs, and the rule does not
care how many there are. Which is the point of writing it as a rule.
