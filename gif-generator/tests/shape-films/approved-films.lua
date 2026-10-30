-- approved-films.lua - the fingerprints of the six films the owner approved.
--
-- What this is, generally: the first six films were approved by the owner
-- on 2026-09-23 exactly as they were then made. Whatever the tool learns
-- afterwards, filming those scenes again must give the very same files; the
-- test re-films each one and compares its SHA-256 fingerprint with the one
-- kept here. The films themselves no longer need to sit in the repository
-- to be checked against: they live in the owner's library
-- (/home/ritz/pictures/shape-gifs/), and these fingerprints were taken from
-- the approved copies before those copies were removed (2026-09-26, when the
-- owner decided the films will not go in the README).
--
-- Data format: scene name -> 64 hexadecimal characters (SHA-256 of the GIF).
return {
    ["breathing-solid"] = "3fb7c585864e2ebd7d4066fb27b60ab9febff4e9a43ddeb818210cd3bbb462e9",
    ["orbit-kiss"] = "21bffdd218fdc2b837e96a997a3381ae928575307fa8d24b0e2985b00a4b13af",
    ["rainbow-stack"] = "400dfa8d563070a7748b8082b4479484e6642046a450667a3b6e01307006cf9f",
    ["reef-school"] = "23a6c190f8ec9fa7cffbbc2708225156c4a95ead4c6672bcad6ad543dc1319dc",
    ["shatter-bloom"] = "b7f4d260e65ba95e0e7e0bb0bf1fe53a84a8d0d5f9a95915656e874ed3b5fcdd",
    ["star-ring-torus"] = "13f97936c01cf731206af59cf6ddf0e1f850760986d69ac3b51ff28dbface291",
}
