we should ensure that the hard drive is not constantly written to, and instead
for progress monitoring and other such frequently updated tasks we should write
to the tmp/ directory (project local symlink to /tmp/) so that our status
updates and other such things are written to RAM, not to disk. This should help
preserve the hardware as best as we can.
