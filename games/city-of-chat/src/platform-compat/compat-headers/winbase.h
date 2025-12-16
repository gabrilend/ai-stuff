#ifndef WINBASE_H_COMPAT
#define WINBASE_H_COMPAT

// Compatibility header for Windows winbase.h on Linux
// Provides Linux equivalents for Windows base API functions

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>

// Windows basic types (if not already defined)
#ifndef HANDLE
typedef void* HANDLE;
#endif

#ifndef DWORD
typedef unsigned long DWORD;
#endif

#ifndef BOOL
typedef int BOOL;
#endif

#ifndef TRUE
#define TRUE 1
#define FALSE 0
#endif

// Windows constants
#define INFINITE 0xFFFFFFFF
#define WAIT_OBJECT_0 0
#define WAIT_TIMEOUT 258
#define WAIT_FAILED 0xFFFFFFFF

#define INVALID_HANDLE_VALUE ((HANDLE)(long)-1)

// File attributes (stub values)
#define FILE_ATTRIBUTE_NORMAL 0x80
#define FILE_ATTRIBUTE_DIRECTORY 0x10
#define FILE_ATTRIBUTE_HIDDEN 0x02

// Generic access rights
#define GENERIC_READ 0x80000000
#define GENERIC_WRITE 0x40000000

// File creation disposition
#define CREATE_NEW 1
#define CREATE_ALWAYS 2
#define OPEN_EXISTING 3
#define OPEN_ALWAYS 4
#define TRUNCATE_EXISTING 5

// File sharing
#define FILE_SHARE_READ 0x01
#define FILE_SHARE_WRITE 0x02

// System time structure
typedef struct _SYSTEMTIME {
    unsigned short wYear;
    unsigned short wMonth;
    unsigned short wDayOfWeek;
    unsigned short wDay;
    unsigned short wHour;
    unsigned short wMinute;
    unsigned short wSecond;
    unsigned short wMilliseconds;
} SYSTEMTIME, *PSYSTEMTIME, *LPSYSTEMTIME;

// File time structure
typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
} FILETIME, *PFILETIME, *LPFILETIME;

// Critical section structure (pthread mutex wrapper)
typedef struct _CRITICAL_SECTION {
    void* DebugInfo;
    long LockCount;
    long RecursionCount;
    void* OwningThread;
    void* LockSemaphore;
    unsigned long SpinCount;
} CRITICAL_SECTION, *PCRITICAL_SECTION, *LPCRITICAL_SECTION;

// Windows API function stubs
static inline void InitializeCriticalSection(CRITICAL_SECTION* cs) {
    // Stub implementation
    memset(cs, 0, sizeof(*cs));
}

static inline void DeleteCriticalSection(CRITICAL_SECTION* cs) {
    // Stub implementation
}

static inline void EnterCriticalSection(CRITICAL_SECTION* cs) {
    // Stub implementation
}

static inline void LeaveCriticalSection(CRITICAL_SECTION* cs) {
    // Stub implementation
}

static inline DWORD GetTickCount(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (tv.tv_sec * 1000) + (tv.tv_usec / 1000);
}

static inline void Sleep(DWORD dwMilliseconds) {
    usleep(dwMilliseconds * 1000);
}

static inline BOOL CloseHandle(HANDLE hObject) {
    return TRUE; // Stub
}

static inline void GetSystemTime(LPSYSTEMTIME lpSystemTime) {
    time_t now = time(NULL);
    struct tm* timeinfo = gmtime(&now);
    if (lpSystemTime && timeinfo) {
        lpSystemTime->wYear = timeinfo->tm_year + 1900;
        lpSystemTime->wMonth = timeinfo->tm_mon + 1;
        lpSystemTime->wDay = timeinfo->tm_mday;
        lpSystemTime->wHour = timeinfo->tm_hour;
        lpSystemTime->wMinute = timeinfo->tm_min;
        lpSystemTime->wSecond = timeinfo->tm_sec;
        lpSystemTime->wMilliseconds = 0;
        lpSystemTime->wDayOfWeek = timeinfo->tm_wday;
    }
}

#endif // WINBASE_H_COMPAT