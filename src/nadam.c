#define _GNU_SOURCE

#include "nadam.h"

#include <search.h>

struct nadamMember {
    struct hsearch_data htabNameMap;
    struct hsearch_data htabHashMap;

    const nadam_messageInfo_t *messageInfos;
    size_t messageCount;
};

// private declarations
// -----------------------------------------------------------------------------
static int checkInitParameters(size_t infoCount, size_t hashLengthMin);
static int makeNameMap(void);

static struct nadamMember nadam;

// interface functions
// -----------------------------------------------------------------------------
int nadam_init(const nadam_messageInfo_t *messageInfos, size_t messageCount, size_t hashLengthMin) {
    int error = checkInitParameters(messageCount, hashLengthMin);
    if (error)
        return error;

    nadam.messageInfos = messageInfos;
    nadam.messageCount = messageCount;

    return makeNameMap();
}

int nadam_setDelegate(const char *name, nadam_recvDelegate_t delegate) {
    return 0; // FIXME
}

int nadam_initiate(nadam_send_t send, nadam_recv_t recv, nadam_errorDelegate_t errorDelegate) {
    return 0; // FIXME
}

int nadam_send(const char *name, const void *msg, uint32_t size) {
    return 0; // FIXME
}

int nadam_sendWin(const char *name, const void *msg, uint32_t size) {
    return nadam_send(name, msg, size); // TODO caching
}

void nadam_stop(void) {
}

// private functions
// -----------------------------------------------------------------------------
static int checkInitParameters(size_t infoCount, size_t hashLengthMin) {
    if (infoCount == 0)
        return NADAM_ERROR_EMPTY_MESSAGE_INFOS;

    if (hashLengthMin < 1 || hashLengthMin > 20)
        return NADAM_ERROR_HASH_LENGTH;

    return 0;
}

static int makeNameMap(void) {
    hdestroy_r(&nadam.htabNameMap);

    return 0; // FIXME
}

