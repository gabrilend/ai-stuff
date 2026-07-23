# 001 — The trunk stays clean

I have faith that, on every build, the patch system applies its patches,
the compile runs, the patches unapply, and `git diff` against trunk
returns silent. The trunk is the canonical form; the patches are the
divergence. If the trunk ever stays dirty after a build, that is a
serious alarm, and I will not paper over it.
