#include <stdint.h>
#include <stdbool.h>

typedef struct {
    bool isVariable;
    union {
        uint32_t total;
        uint32_t max;
    };
} nadam_messageSize_t;

typedef struct {
    const char *name;
    size_t nameLength;
    nadam_messageSize_t size;
    uint8_t hash[20];
} nadam_messageInfo_t;

#define NADAM_ERROR_ // FIXME what was that again?
#define NADAM_ERROR_UNKNOWN_NAME
#define NADAM_ERROR_NAME_COLLISION
#define NADAM_ERROR_HASH_COLLISION
// errors passed to the error delegate
#define NADAM_ERROR_HASH_LENGTH_HANDSHAKE
#define NADAM_ERROR_CONNECTION_CLOSED
#define NADAM_ERROR_UNKNOWN_HASH
#define NADAM_ERROR_VARIABLE_SIZE

typedef int (*nadam_send_t)(const void *src, uint32_t n);
typedef int (*nadam_recv_t)(void *dest, uint32_t n);
// after a delegate returns, memory pointed to by msg should be considered invalid
// size argument is intended for messages of variable size
typedef void (*nadam_recvDelegate_t)(void *msg, uint32_t size, const nadam_messageInfo_t *messageInfo);

// if the error delegate gets called, no new messages will be received (the connection should be closed)
typedef void (*nadam_errorDelegate_t)(int error);

/*
 * Modern languages shouldn't care about a string being zero terminated.
 * To make C implementation fully compliant, one would need to pass the length with every name.
 * That would be painful, therefore the follwing compromise was made:
 * name's length is assumed to be the index of first '\0'.
 * The limitation of this is that all names truncated at first '\0' have to be unique.
 * Otherwise nadam_init() would fail. nameLength in nadam_messageInfo_t is endowed
 * by message type generator utility, but is ignored in this implementation.
 */

// infoList memory shouldn't be freed until after nadam_initiate() call
int nadam_init(const nadam_messageInfo_t *messageInfos, size_t infoCount, size_t hashLengthMin);

// if the delegate for a message type is not set, messages of this type are ignored (dumped)
int nadam_setDelegate(const char *name, nadam_recvDelegate_t delegate);

int nadam_initiate(nadam_send_t send, nadam_recv_t recv, nadam_errorDelegate_t errorDelegate);

// size argument is ignored for constant size messages
int nadam_send(const char *name, const void *msg, uint32_t size);
/*
 * Calling this send version (Send With Immutable Name) promises, that the name is a string literal or memory,
 * whose content won't change throughout the life of the program - allowes name lookup caching.
 */
int nadam_sendWin(const char *name, const void *msg, uint32_t size);

void nadam_stop(void);

