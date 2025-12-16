#ifndef EXCPT_H_COMPAT
#define EXCPT_H_COMPAT

// Compatibility header for Windows excpt.h on Linux
// Provides structured exception handling stubs

#include <setjmp.h>
#include <signal.h>

// Exception filter return values
#define EXCEPTION_EXECUTE_HANDLER 1
#define EXCEPTION_CONTINUE_SEARCH 0
#define EXCEPTION_CONTINUE_EXECUTION -1

// Exception codes
#define EXCEPTION_ACCESS_VIOLATION 0xC0000005
#define EXCEPTION_ARRAY_BOUNDS_EXCEEDED 0xC000008C
#define EXCEPTION_BREAKPOINT 0x80000003
#define EXCEPTION_DATATYPE_MISALIGNMENT 0x80000002
#define EXCEPTION_FLT_DENORMAL_OPERAND 0xC000008D
#define EXCEPTION_FLT_DIVIDE_BY_ZERO 0xC000008E
#define EXCEPTION_FLT_INEXACT_RESULT 0xC000008F
#define EXCEPTION_FLT_INVALID_OPERATION 0xC0000090
#define EXCEPTION_FLT_OVERFLOW 0xC0000091
#define EXCEPTION_FLT_STACK_CHECK 0xC0000092
#define EXCEPTION_FLT_UNDERFLOW 0xC0000093
#define EXCEPTION_ILLEGAL_INSTRUCTION 0xC000001D
#define EXCEPTION_IN_PAGE_ERROR 0xC0000006
#define EXCEPTION_INT_DIVIDE_BY_ZERO 0xC0000094
#define EXCEPTION_INT_OVERFLOW 0xC0000095
#define EXCEPTION_INVALID_DISPOSITION 0xC0000026
#define EXCEPTION_NONCONTINUABLE_EXCEPTION 0xC0000025
#define EXCEPTION_PRIV_INSTRUCTION 0xC0000096
#define EXCEPTION_SINGLE_STEP 0x80000004
#define EXCEPTION_STACK_OVERFLOW 0xC00000FD

// Exception record structure (simplified)
typedef struct _EXCEPTION_RECORD {
    unsigned long ExceptionCode;
    unsigned long ExceptionFlags;
    struct _EXCEPTION_RECORD *ExceptionRecord;
    void *ExceptionAddress;
    unsigned long NumberParameters;
    uintptr_t ExceptionInformation[15];
} EXCEPTION_RECORD, *PEXCEPTION_RECORD;

// Context record (stub)
typedef struct _CONTEXT {
    unsigned long ContextFlags;
    // Simplified - real structure is much larger
    uintptr_t registers[32];
} CONTEXT, *PCONTEXT;

// Exception pointers
typedef struct _EXCEPTION_POINTERS {
    PEXCEPTION_RECORD ExceptionRecord;
    PCONTEXT ContextRecord;
} EXCEPTION_POINTERS, *PEXCEPTION_POINTERS;

// Exception filter function type
typedef long (*PTOP_LEVEL_EXCEPTION_FILTER)(PEXCEPTION_POINTERS ExceptionInfo);

// Structured exception handling macros (stubs for Linux)
#define __try if (1)
#define __except(filter) if (0)
#define __finally 
#define __leave goto __leave_label; __leave_label:

// Exception handling functions (stubs)
static inline PTOP_LEVEL_EXCEPTION_FILTER SetUnhandledExceptionFilter(PTOP_LEVEL_EXCEPTION_FILTER lpTopLevelExceptionFilter) {
    return NULL;
}

static inline unsigned long GetExceptionCode(void) {
    return 0;
}

static inline PEXCEPTION_POINTERS GetExceptionInformation(void) {
    return NULL;
}

static inline void RaiseException(unsigned long dwExceptionCode, unsigned long dwExceptionFlags, 
                                  unsigned long nNumberOfArguments, const uintptr_t *lpArguments) {
    // Stub implementation
}

#endif // EXCPT_H_COMPAT