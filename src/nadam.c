#define _GNU_SOURCE

#include "nadam.h"

#include <errno.h>
#include <assert.h>

#include <search.h>

struct nadamMember {
    struct hsearch_data nameKeyHtab;
    struct hsearch_data hashKeyHtab;

    const nadam_messageInfo_t *messageInfos;
    size_t messageCount;
    size_t hashLength;
};

// private declarations
// -----------------------------------------------------------------------------
static int testInitIn(size_t infoCount, size_t hashLengthMin);
static void cleanHtabs(void);
static int fillNameMap(void);

static struct nadamMember nadam;

// interface functions
// -----------------------------------------------------------------------------
int nadam_init(const nadam_messageInfo_t *messageInfos, size_t messageCount, size_t hashLengthMin) {
    if (testInitIn(messageCount, hashLengthMin))
        return -1;

    nadam.messageInfos = messageInfos;
    nadam.messageCount = messageCount;
    nadam.hashLength = hashLengthMin;

    cleanHtabs();

    bool success = hcreate_r(messageCount, &nadam.nameKeyHtab);
    assert(success);

    return fillNameMap();
}

// FIXME dummies
int nadam_setDelegate(const char *name, nadam_recvDelegate_t delegate) {
    return 0;
}

int nadam_initiate(nadam_send_t send, nadam_recv_t recv, nadam_errorDelegate_t errorDelegate) {
    return 0;
}

int nadam_send(const char *name, const void *msg, uint32_t size) {
    return 0;
}

int nadam_sendWin(const char *name, const void *msg, uint32_t size) {
    return nadam_send(name, msg, size); // TODO caching
}

void nadam_stop(void) {
}

// private functions
// -----------------------------------------------------------------------------
static int testInitIn(size_t infoCount, size_t hashLengthMin) {
    if (infoCount == 0) {
        errno = NADAM_ERROR_EMPTY_MESSAGE_INFOS;
        return -1;
    }

    if (hashLengthMin < 1 || hashLengthMin > 20) {
        errno = NADAM_ERROR_HASH_LENGTH_MIN;
        return -1;
    }

    return 0;
}

static void cleanHtabs(void) {
    static const struct hsearch_data zeroHtab = { 0 };

    hdestroy_r(&nadam.nameKeyHtab);
    nadam.nameKeyHtab = zeroHtab;
    hdestroy_r(&nadam.hashKeyHtab);
    nadam.hashKeyHtab = zeroHtab;
}

static int fillNameMap(void) {
    for (size_t i = 0; i < nadam.messageCount; i++) {
        const nadam_messageInfo_t *mip = &nadam.messageInfos[i];
        ENTRY *ep, e = { .key = (char *) mip->name, .data = (void *) mip };

        bool success = hsearch_r(e, ENTER, &ep, &nadam.nameKeyHtab);
        assert(success);

        if (e.data != ep->data) {
            errno = NADAM_ERROR_NAME_COLLISION;
            return -1;
        }
    }

    return 0;
}

