//=============================================================================
// SR_SymbelineRumbleMutator
//
// Main mutator class for UT2K4 Symbeline Rumble mod. This is the entry point
// for the modification and handles initialization of all game systems.
//
// Naming Convention: SR_ prefix for SymbelineRumble
//
// Phase: 1 - Foundation and Basic Infrastructure
// Issue: 102 - Create Basic Mod Package Structure
//=============================================================================
class SR_SymbelineRumbleMutator extends Mutator;

//=============================================================================
// Variables
//=============================================================================
var string ModVersion;
var float InitTime;

//=============================================================================
// GetDescription
//
// Returns a human-readable description of this mutator for the game UI.
// This appears in the mutator selection menu.
//=============================================================================
simulated function string GetDescription()
{
    return "UT2K4 Symbeline Rumble - Warcraft Rumble-style gameplay mod";
}

//=============================================================================
// PostBeginPlay
//
// Called after the mutator is spawned and initialized. This is where we
// set up our game systems and modify the base game behavior.
//=============================================================================
function PostBeginPlay()
{
    Super.PostBeginPlay();

    InitTime = Level.TimeSeconds;
    Log("SR_SymbelineRumbleMutator" @ ModVersion @ ": Initialized at time" @ InitTime);
}

defaultproperties
{
    GroupName="SymbelineRumble"
    FriendlyName="Symbeline Rumble"
    Description="Warcraft Rumble-style gameplay for UT2004"
    ModVersion="0.1.0-phase1"
    bAddToServerPackages=True
}
