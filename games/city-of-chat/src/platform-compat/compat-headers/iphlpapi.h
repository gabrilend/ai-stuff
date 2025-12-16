#ifndef IPHLPAPI_H_COMPAT
#define IPHLPAPI_H_COMPAT

// Compatibility header for Windows iphlpapi.h on Linux
// Provides Linux equivalents for IP Helper API functions

#include <sys/types.h>
#include <sys/socket.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <arpa/inet.h>

// Windows IP helper constants and types
#define MAX_ADAPTER_NAME_LENGTH 256
#define MAX_ADAPTER_DESCRIPTION_LENGTH 128
#define MAX_ADAPTER_ADDRESS_LENGTH 8

typedef DWORD ULONG;
typedef ULONG* PULONG;
typedef BYTE* PBYTE;

// IP address information structure (simplified)
typedef struct _IP_ADDR_STRING {
    struct _IP_ADDR_STRING* Next;
    char IpAddress[16];
    char IpMask[16];
    DWORD Context;
} IP_ADDR_STRING, *PIP_ADDR_STRING;

// Adapter information structure (simplified)
typedef struct _IP_ADAPTER_INFO {
    struct _IP_ADAPTER_INFO* Next;
    DWORD ComboIndex;
    char AdapterName[MAX_ADAPTER_NAME_LENGTH + 4];
    char Description[MAX_ADAPTER_DESCRIPTION_LENGTH + 4];
    UINT AddressLength;
    BYTE Address[MAX_ADAPTER_ADDRESS_LENGTH];
    DWORD Index;
    UINT Type;
    UINT DhcpEnabled;
    PIP_ADDR_STRING CurrentIpAddress;
    IP_ADDR_STRING IpAddressList;
    IP_ADDR_STRING GatewayList;
    IP_ADDR_STRING DhcpServer;
    BOOL HaveWins;
    IP_ADDR_STRING PrimaryWinsServer;
    IP_ADDR_STRING SecondaryWinsServer;
    time_t LeaseObtained;
    time_t LeaseExpires;
} IP_ADAPTER_INFO, *PIP_ADAPTER_INFO;

// Windows IP Helper API function stubs
static inline DWORD GetAdaptersInfo(PIP_ADAPTER_INFO pAdapterInfo, PULONG pOutBufLen) {
    // Stub implementation - would need to enumerate network interfaces
    if (pOutBufLen) *pOutBufLen = 0;
    return ERROR_NO_DATA;
}

// Error constants
#ifndef ERROR_BUFFER_OVERFLOW
#define ERROR_BUFFER_OVERFLOW 111L
#endif

#ifndef ERROR_NO_DATA
#define ERROR_NO_DATA 232L
#endif

#ifndef ERROR_SUCCESS
#define ERROR_SUCCESS 0L
#endif

#endif // IPHLPAPI_H_COMPAT