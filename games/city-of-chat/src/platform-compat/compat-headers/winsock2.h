#ifndef WINSOCK2_H_COMPAT
#define WINSOCK2_H_COMPAT

// Compatibility header for Windows winsock2.h on Linux
// Provides Linux socket equivalents

#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

// Windows socket types to Linux mappings
typedef int SOCKET;
typedef struct sockaddr_in SOCKADDR_IN;
typedef struct sockaddr SOCKADDR;
typedef struct hostent HOSTENT;

// Windows socket constants
#define INVALID_SOCKET (-1)
#define SOCKET_ERROR (-1)

// Windows socket options (map to Linux equivalents)
#define SO_DONTLINGER   (~SO_LINGER)
#define WSADESCRIPTION_LEN 256
#define WSASYS_STATUS_LEN 128

// Windows Winsock version info structure (stub)
typedef struct WSAData {
    unsigned short wVersion;
    unsigned short wHighVersion;
    char szDescription[WSADESCRIPTION_LEN+1];
    char szSystemStatus[WSASYS_STATUS_LEN+1];
    unsigned short iMaxSockets;
    unsigned short iMaxUdpDg;
    char* lpVendorInfo;
} WSADATA, *LPWSADATA;

// Windows socket functions mapped to Linux equivalents
#define WSAStartup(version, wsadata) (0)
#define WSACleanup() (0)
#define WSAGetLastError() errno
#define closesocket(s) close(s)
#define ioctlsocket(s, cmd, argp) ioctl(s, cmd, argp)

// Address family constants
#ifndef AF_INET
#define AF_INET 2
#endif

// Protocol constants  
#ifndef IPPROTO_TCP
#define IPPROTO_TCP 6
#endif

#ifndef IPPROTO_UDP
#define IPPROTO_UDP 17
#endif

// Socket type constants
#ifndef SOCK_STREAM
#define SOCK_STREAM 1
#endif

#ifndef SOCK_DGRAM
#define SOCK_DGRAM 2
#endif

#endif // WINSOCK2_H_COMPAT