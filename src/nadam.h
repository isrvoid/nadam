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

typedef int (*nadam_send_t)(const void *src, uint32_t n);
typedef int (*nadam_recv_t)(void *dest, uint32_t n);
// after a delegate returns, memory pointed to by msg should be considered invalid
// size argument is intended for messages of variable size
typedef void (*nadam_delegate_t)(void *msg, uint32_t size, const nadam_messageInfo_t *messageInfo);

// infoList memory shouldn't be freed until after nadam_initiate() call
int nadam_init(const nadam_messageInfo_t *messageInfos, size_t infoCount, size_t hashLengthMin);

// if the delegate for a message type is not set, messages of this type are ignored (dumped)
int nadam_setDelegate(const char *name, size_t nameLength, nadam_delegate_t delegate);

int nadam_initiate(nadam_send_t send, nadam_recv_t recv);

// size argument is ignored for constant size messages
int nadam_send(const char *name, size_t nameLength, const void *msg, uint32_t size);

void nadam_terminate(void);

