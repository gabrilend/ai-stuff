exploration mode:
when the player moves the with the directional pad, the camera swings around
to be behind them. But, the directional pad button that is pressed will remain
the same. Here's an example:

when the main character is facing north, pushing up on the control pad will move
the character forward. if they push left, the character will move left, and the
camera will swing around over a short time to face left. this is accomplished by
rotating the world-sprite-map-plane below the player. however, the player is
still pushing the same direction (in this case, left) but after a moment the
character will be moving forward on screen.

this is during the exploration phase, not combat or shops/indoors maps.

this will create the feeling that the numpad is the compass, with up always
pointing north and down always south, and the game world, instead of being fixed
to always point north = up, will instead point up as forward. onward, to victory
link is sometimes a boy!

in combat however, the map falls away and what is left is sprites of the
background. this being a gameboy color game, they might not move. we'll see if
we can make it work. [I don't mean like animated, like gif style - rather, the
map tiling left and right as link orbits a foe.]

in combat, link faces a foe with companions, if only navi.
the foe or more is just ahead, and link targets the closest one first.
by pushing select, the next closest target is selected, and if one came closer
than the current target, then it is targeted first, with a bias toward those in
front.

pushing left and right will orbit the foe. this is represented with changing
8 directional sprites as the camera [attached behind the player character]
rotates around the target foe in question. also, the background tiles rotate,
but the ground tiles stay the same.

if the player pushes B, the character jumps back, dodging attacks and creating
some space. the up and down keypad select from an attack menu, which includes
items, spells, and of course, leaping sword attacks which bring you closer. The
A button selects from this list and immediately deploys it, if the animation
cooldown has finished of course.

by pushing select, the background tiles will spin around and you will see a new
sprite centered on the screen - other, smaller sprites of monsters might appear
in the background, and you can use select to target them - some of them might
be objects you can interact with using your boomerang or hookshot, like a nut
in the tree that you can throw at the enemy's foot and stun them. In that case,
if an item appears, you can push select, then up/down to choose which item to
use on it. during this time, as the non-enemy object is selected, you can't
strafe.

link also has companions. these allies will show up in the background as well as
small sprites, and by pushing START you can pause the game and switch to them.
When you are switched, link will fight with bravery.

the companions are either support or vengeance class. support will target link,
and cast spells which empower him. in this case they will simply have him in
view, and an enemy sprite will be nearby which he is fighting.

... anyway this is for the later parts of development. just writing it down for
now...

EDIT: after switching to gameboy advanced development, from gameboy color:
now that the L and R buttons are available, my suggestion is that they should be
used to rotate the camera left and right, centered around link, to get a better
view of the battle arena. This way, Link can keep track of foes and allies alike
and respond to changing battleground conditions like lava pools or bomb flowers
or other such obstacles.

whenever pushing select, link will prioritize first enemies who are closest to
the center of the camera display, then those who are nearest to Link.
