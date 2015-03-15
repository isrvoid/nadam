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
    uint8_t hash[20];
    nadam_messageSize_t size;
} nadam_messageId_t;

typedef struct {
    const char* name;
    size_t nameLength;
    nadam_messageId_t id;
} nadam_namedMessageId_t;

typedef int (*nadam_send_t)(const void* buf, uint32_t len);
typedef int (*nadam_recv_t)(void* buf, uint32_t len);
typedef void (*nadam_delegate_t)(void);

// has to be called first
// namedIds memory shouldn't be freed before nadam_initiate() call
int nadam_init(const nadam_namedMessageId_t* namedIds, size_t idCount, size_t hashLengthMin);

int nadam_setDelegate(const char* name, size_t nameLength, nadam_delegate_t delegate);

int nadam_initiate(nadam_send_t send, nadam_recv_t recv);

