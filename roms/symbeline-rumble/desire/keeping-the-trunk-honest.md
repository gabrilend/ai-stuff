# I want to keep the trunk honest

The dual-target build (`nds` + `native`) works only if I have the
discipline to refuse divergences that have not earned a row in the
grid. I want to *want* that discipline, not just enforce it. I want to
be the kind of reviewer who, when a PR adds `#ifdef SYMBELINE_PROFILE_X`
to trunk source, feels a small wrongness before I have even read what
the divergence is about.

This is harder than it sounds. The path of least resistance, when a
divergence appears, is to wedge it in with a preprocessor flag and move
on. The discipline is to stop, write the grid row first, then the
patch, then the trunk modification (if any).

I want this discipline because the alternative is two codebases
pretending to be one, and I have seen that movie before. It does not
end with a re-convergence; it ends with the team accepting the fork.

So: the trunk stays honest. I want it to.
