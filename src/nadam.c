#define _GNU_SOURCE

#include "nadam.h"

#include <assert.h>

#include <search.h>

struct nadamMember {
    struct hsearch_data nameKeyHtab;
    struct hsearch_data hashKeyHtab;

    const nadam_messageInfo_t *messageInfos;
    size_t messageCount;
};

// private declarations
// -----------------------------------------------------------------------------
static int testInitIn(size_t infoCount, size_t hashLengthMin);
static int fillNameMap(void);

static struct nadamMember nadam;

// interface functions
// -----------------------------------------------------------------------------
int nadam_init(const nadam_messageInfo_t *messageInfos, size_t messageCount, size_t hashLengthMin) {
    int error = testInitIn(messageCount, hashLengthMin);
    if (error)
        return error;

    nadam.messageInfos = messageInfos;
    nadam.messageCount = messageCount;

    bool success = hcreate_r(messageCount, &nadam.nameKeyHtab);
    assert(success);

    return fillNameMap();
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
static int testInitIn(size_t infoCount, size_t hashLengthMin) {
    if (infoCount == 0)
        return NADAM_ERROR_EMPTY_MESSAGE_INFOS;

    if (hashLengthMin < 1 || hashLengthMin > 20)
        return NADAM_ERROR_HASH_LENGTH;

    return 0;
}

static int fillNameMap(void) {
    for (size_t i = 0; i < nadam.messageCount; i++) {
        const nadam_messageInfo_t *mip = &nadam.messageInfos[i];
        ENTRY *ep, e = { .key = (char *) mip->name, .data = (void *) mip };

        bool success = hsearch_r(e, ENTER, &ep, &nadam.nameKeyHtab);
        assert(success);

        if (e.data != ep->data)
            return NADAM_ERROR_NAME_COLLISION;
    }

    return 0;
}

