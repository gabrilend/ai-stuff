anbernic RG DS operating system.

four main applications. paint is the last one built — and pictochat
isn't done until paint is, because pictochat sends images to peers
and the images come from paint.

first is a soramech based programming language.

second is i3 style text editor, two panels per screen, 40 character
width unless they do double-width and then it's 80 character width.
pressing L+R at the same time swaps between cursor mode and insert
mode, like vim. text input is via radial menu*.

third is pictochat, essentially. with painted images attached.

fourth is paint. stylus on either touch screen draws. buttons select
tools and colors. saved drawings become the attachments pictochat
sends.

apps don't get switched between with a switcher. they link to each
other, like soramech boxes calling each other. each app exposes a
list of exits — each exit names the app it goes to and the value
it carries forward. pressing an exit follows the link; the screen
shows the next app. there is no back button. the user only moves
forward. if you want to come back to where you were, the app you
arrived at will have a link that takes you there — often with a
result attached. apps that naturally pair (paint and pictochat,
editor and files) cross-link both directions, like a doubly-linked
list. apps that don't pair just don't. no history stack, no ring
buffer — background apps keep their state and a forward link back
to them resumes that state where the user left it.

the four center buttons across the bottom of the lower screen are
[start1][select1][select2][start2]. each one opens a drawer:

  start1     → bottom-left drawer
  select1    → bottom-right drawer
  select2    → top-left drawer
  start2     → top-right drawer

an option in the menu swaps which screen the pairs reach. set the
swap and start1/select1 then open the top screen's drawers,
start2/select2 the bottom screen's.

drawers slide in fast from the entire left or right edge of their
screen — not the corner, the full edge. they're as tall as the
screen minus about 5% of margin on every side, so it's obvious you
opened a menu. close them and they slide back off the same edge.
inside a drawer is whatever utility belongs there — often a radial
interface for picking among options.

*radial menu: push the D-pad in a direction and it shows a circular
              menu which has 4 characters that you can type by
              pushing one of the AB/XY buttons. Essentially a chord
              created with one button from your left hand, and one
              button from your right hand. the D-pad has eight
              directions, not four — diagonals count, the user
              learns this. eight directions × four face buttons =
              thirty-two characters per mode. analog sticks work
              the same way, eight directions, also chorded with a
              face button. L/R triggers switch between modes — two
              triggers per side gives four or more modes, which is
              enough for the alphabet, digits, and punctuation
              without scrolling. one cursor at a time, one attention
              focus point, the user switches between panels rather
              than splitting their head in two.

later, a fifth application: the modeller. on-device 3D modelling,
vertex grid editing, face coloring through the radial menu, dynamic
merging of models like lego. it depends on so much of the rest of
the system that it doesn't ship at launch, but the seed is here.

system is multithreaded by default. the entire OS above the C
language layer is a soramech map.

we never run the stock OS. not once. the stock OS has to assume
we're not using their device.
