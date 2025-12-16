#ifndef SHARE_H_COMPAT
#define SHARE_H_COMPAT

// Compatibility header for Windows share.h on Linux
// Provides file sharing constants used by _open(), _sopen(), etc.

// File sharing flags for Windows _sopen function
#define _SH_COMPAT   0x00    // Compatibility mode
#define _SH_DENYRW   0x10    // Deny read/write access to others
#define _SH_DENYWR   0x20    // Deny write access to others  
#define _SH_DENYRD   0x30    // Deny read access to others
#define _SH_DENYNO   0x40    // Allow read/write access to others

// On Linux, these flags don't have direct equivalents since file sharing
// works differently with fcntl() and flock(), but we provide the constants
// so the code compiles

#endif // SHARE_H_COMPAT