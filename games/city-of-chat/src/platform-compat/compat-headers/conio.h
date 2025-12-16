#ifndef CONIO_H_COMPAT
#define CONIO_H_COMPAT

// Compatibility header for Windows conio.h on Linux
// Provides basic console I/O function stubs

#include <stdio.h>
#include <termios.h>
#include <unistd.h>

// Console function stubs (basic implementations)
static inline int _kbhit(void) {
    // Simplified implementation - always return 0 (no key hit)
    return 0;
}

static inline int _getch(void) {
    return getchar();
}

static inline int _getche(void) {
    int ch = getchar();
    putchar(ch);
    return ch;
}

static inline void _clrscr(void) {
    printf("\033[2J\033[H");
}

// No-op definitions for Windows-specific console functions
#define _cprintf printf
#define _cputs puts

#endif // CONIO_H_COMPAT