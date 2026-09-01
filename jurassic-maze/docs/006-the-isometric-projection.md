# The Isometric Projection

Three numbers go in — a cell's x, its y, and a height in layers — and two come
out: a position on the screen. This page is that arithmetic, and the two
properties of it that the renderer is built on.

## The projection

    screen_x = (x - y) * half_width  +  pan_x
    screen_y = (x + y) * half_height  -  height * layer_pixels  +  pan_y

`half_width` and `half_height` are half the size of a cell's diamond on screen.
The reference picture is a **two-to-one** isometric — a cell is twice as wide as
it is tall — so `half_width` is twice `half_height`. That ratio is a measured
observation about the picture and it lives in
[the inspiration notice](../inspiration/NOTICE.md) beside the other
measurements, not scattered through the code.

Two-to-one rather than a true 30-degree isometric because two-to-one means every
diamond edge advances exactly two pixels across for one down. Diagonal edges land
on whole pixels, and the stone reads as stone instead of as a stack of slightly
wrong staircases. It is the reason essentially every hand-drawn isometric
picture ever made is two-to-one, including the one this project is copying.

`layer_pixels` is how many pixels tall one stone layer is. It is independent of
the cell size, and having it be independent is what lets the maze be squat or
towering without the floor plan changing.

## The first property: increasing x plus y is toward the viewer

Everything in this projection that is nearer to the person looking at it has a
larger `x + y`. That single fact is what makes drawing possible without a depth
buffer, and it has a consequence that matters more than it looks:

> The correct back-to-front draw order is `for y ascending, for x ascending`.

And the columns are stored at index `x + y * width`. So **the correct draw order
is exactly the array's own memory order.** The render pass is a linear sweep from
the first element to the last, in the direction the prefetcher is already going.

This is not a coincidence that was noticed afterwards and enjoyed. It is why the
index is `x + y * width` and not `y + x * depth`. Reversing the index would have
made the draw pass walk memory in strides, in exchange for nothing.

There is a **second** correct order, and the renderer uses it. Cells sharing one
value of `x + y` lie on a band across the screen and none of them can occlude any
other — their diamonds sit side by side and exactly touch — so band by band is
equally valid. That order matters because **bodies have to be drawn between the
bands**: the stone is baked into one static mesh, a mesh drawn in one call is
drawn all at once, and a ball drawn after it would sit on top of every wall in
the maze including the ones in front of it. See
[drawing a pile of stones](007-drawing-a-pile-of-stones.md).

## The second property: it inverts

Given a point on the screen, the cell under it comes back out:

    u = (screen_x - pan_x) / half_width          -- this is x - y
    v = (screen_y - pan_y) / half_height         -- this is x + y, at height zero
    x = (u + v) / 2
    y = (v - u) / 2

That inversion is used for three things and each one would otherwise be a
search:

- **Culling.** Invert the four corners of the window and get a range of cells to
  draw. Everything outside is skipped without being considered.
- **The mouse.** Pointing at the maze and being told which cell that is.
- **The camera.** Centring on a body means inverting the window's middle.

The inversion is only exact at height zero. A tall column's top face is drawn
`height * layer_pixels` further up the screen than its ground position, so a
click that lands on a wall's top face reports the cell *behind* the one being
looked at. Fixing that properly means marching down the ray, layer by layer,
until a solid one is hit — a handful of iterations, done once per click, and
worth it because the alternative is a mouse that lies about tall geometry.

## Culling with tall columns

A column of height `h` is drawn up to `h * layer_pixels` above its ground
position. A naive cull that inverts the viewport corners will therefore drop
columns whose base is below the window but whose top face is inside it — walls
would vanish from the bottom edge of the screen as you scroll.

The fix is to extend the inverted range by `layers * layer_pixels / half_height`
cells in the direction of increasing `x + y`. That is the tallest a column can
be, converted into how many cells of `x + y` it can reach across. It
overestimates for a maze that is mostly short, and overestimating costs a few
skipped cells at the edge, which is the correct direction to be wrong in.

## Related documents and tools

- [Drawing a pile of stones](007-drawing-a-pile-of-stones.md) — what gets drawn once this says where
- [The camera and what it watches](008-the-camera-and-what-it-watches.md) — what supplies the pan and the scale
