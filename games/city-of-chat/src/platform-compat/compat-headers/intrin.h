#ifndef INTRIN_H_COMPAT
#define INTRIN_H_COMPAT

// Compatibility header for Windows intrin.h on Linux
// Provides GCC equivalents for MSVC intrinsics

#ifdef __GNUC__

// Include GCC intrinsics but avoid conflicts
#include <immintrin.h>
#include <x86intrin.h>
#include <cpuid.h>

// MSVC intrinsic mappings to GCC equivalents (only if not already defined)
#ifndef __cpuid_defined
#define __cpuid_defined
static inline void __cpuid_compat(int info[4], int func) {
    __cpuid_count(func, 0, info[0], info[1], info[2], info[3]);
}
#define __cpuid __cpuid_compat
#endif

#define _BitScanForward __builtin_ctzl
#define _BitScanReverse(index, mask) ((mask) ? (*(index) = 31 - __builtin_clzl(mask), 1) : 0)

// Memory barriers
#define _ReadBarrier() __asm__ __volatile__("": : :"memory")
#define _WriteBarrier() __asm__ __volatile__("": : :"memory")
#define _ReadWriteBarrier() __asm__ __volatile__("": : :"memory")

// Atomic operations
#define _InterlockedIncrement(ptr) __sync_add_and_fetch(ptr, 1)
#define _InterlockedDecrement(ptr) __sync_sub_and_fetch(ptr, 1)
#define _InterlockedExchange(ptr, value) __sync_lock_test_and_set(ptr, value)
#define _InterlockedExchangeAdd(ptr, value) __sync_fetch_and_add(ptr, value)
#define _InterlockedCompareExchange(ptr, exchange, comparand) __sync_val_compare_and_swap(ptr, comparand, exchange)

// Rotation intrinsics (use GCC built-ins if available, otherwise manual implementation)
#ifndef _rotl
#define _rotl(value, shift) (((value) << (shift)) | ((value) >> (32 - (shift))))
#endif
#ifndef _rotr  
#define _rotr(value, shift) (((value) >> (shift)) | ((value) << (32 - (shift))))
#endif
#define _rotl64(value, shift) (((value) << (shift)) | ((value) >> (64 - (shift))))
#define _rotr64(value, shift) (((value) >> (shift)) | ((value) << (64 - (shift))))

// Byte swapping
#define _byteswap_ushort(x) __builtin_bswap16(x)
#define _byteswap_ulong(x) __builtin_bswap32(x)
#define _byteswap_uint64(x) __builtin_bswap64(x)

// Performance counter
static inline unsigned long long __rdtsc(void) {
    unsigned int lo, hi;
    __asm__ __volatile__ ("rdtsc" : "=a" (lo), "=d" (hi));
    return ((unsigned long long)hi << 32) | lo;
}

// Compiler hints
#define __assume(x) do { if (!(x)) __builtin_unreachable(); } while(0)
#define __nop() __asm__ __volatile__("nop")
#define __debugbreak() __asm__ __volatile__("int3")

#else
// Non-GCC compiler - provide basic stubs
#define __cpuid(info, func) memset(info, 0, sizeof(int) * 4)
#define _BitScanForward(index, mask) 0
#define _BitScanReverse(index, mask) 0
#define _ReadBarrier()
#define _WriteBarrier() 
#define _ReadWriteBarrier()
#define _InterlockedIncrement(ptr) (++(*ptr))
#define _InterlockedDecrement(ptr) (--(*ptr))
#define _InterlockedExchange(ptr, value) (*ptr = value)
#define _InterlockedExchangeAdd(ptr, value) (*ptr += value)
#define _InterlockedCompareExchange(ptr, exchange, comparand) (*ptr = exchange)
#define _rotl(value, shift) value
#define _rotr(value, shift) value
#define _rotl64(value, shift) value
#define _rotr64(value, shift) value
#define _byteswap_ushort(x) x
#define _byteswap_ulong(x) x
#define _byteswap_uint64(x) x
#define __rdtsc() 0ULL
#endif

#endif // INTRIN_H_COMPAT