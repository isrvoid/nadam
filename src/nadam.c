/*
Copyright:  Copyright Johannes Teichrieb 2015
License:    opensource.org/licenses/MIT
*/
#include "nadam.h"

#include <errno.h>
#include <assert.h>

#include "khash.h"

#include "unittestMacros.h"

KHASH_MAP_INIT_INT(m32, size_t)
KHASH_MAP_INIT_STR(mStr, size_t)

typedef struct {
    nadam_recvDelegate_t delegate;
    void *recvBuffer;
    volatile bool *recvStart;
} recvDelegateRelated_t;

struct nadamMembers {
    khash_t(mStr) *nameKeyMap;
    khash_t(m32) *hashKeyMap;

    void *commonRecvBuffer;
    recvDelegateRelated_t *delegates;

    const nadam_messageInfo_t *messageInfos;
    size_t messageCount;
    size_t hashLength;

    nadam_send_t send;
    nadam_recv_t recv;

    nadam_errorDelegate_t errorDelegate;
};

// private declarations
// -----------------------------------------------------------------------------
static int testInitIn(size_t infoCount, size_t hashLengthMin);
static void freeMembers(void);
static int allocateMembers(void);
static int allocate(void **dest, size_t size);
static uint32_t getMaxMessageSize(void);
static void initMaps(void);
static int fillNameMap(void);

static struct nadamMembers mbr;

// interface functions
// -----------------------------------------------------------------------------
int nadam_init(const nadam_messageInfo_t *messageInfos, size_t messageCount, size_t hashLengthMin) {
    if (testInitIn(messageCount, hashLengthMin))
        return -1;

    freeMembers();
    memset(&mbr, 0, sizeof(mbr));

    mbr.messageInfos = messageInfos;
    mbr.messageCount = messageCount;
    mbr.hashLength = hashLengthMin;

    if (allocateMembers())
        return -1;

    initMaps();

    return fillNameMap();
}

int nadam_setDelegate(const char *msgName, nadam_recvDelegate_t delegate) {
    return nadam_setDelegateWithRecvBuffer(msgName, delegate, mbr.commonRecvBuffer, NULL);
}

// FIXME dummies
int nadam_setDelegateWithRecvBuffer(const char *msgName, nadam_recvDelegate_t delegate,
        void *buffer, volatile bool *recvStart) {
    assert(buffer);

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

    /* For initial implementation let's assume that
       all hashes can be uniquely distinguished by the first 4 bytes
       TODO extension for lengths (4,8] with uint64_t keys  */
    if (hashLengthMin == 0 || hashLengthMin > 4) {
        errno = NADAM_ERROR_MIN_HASH_LENGTH;
        return -1;
    }

    return 0;
}

static void freeMembers(void) {
    kh_destroy(mStr, mbr.nameKeyMap);
    kh_destroy(m32, mbr.hashKeyMap);
    free(mbr.commonRecvBuffer);
    free(mbr.delegates);
    // messageInfos are not ours to free
}

static int allocateMembers(void) {
    if (allocate(&mbr.commonRecvBuffer, getMaxMessageSize()))
        return -1;

    if (allocate((void **) &mbr.delegates, sizeof(recvDelegateRelated_t) * mbr.messageCount))
        return -1;

    return 0;
}

static int allocate(void **dest, size_t size) {
    *dest = malloc(size);
    if (!*dest) {
        errno = NADAM_ERROR_MALLOC_FAILED;
        return -1;
    }
    return 0;
}

static uint32_t getMaxMessageSize(void) {
    uint32_t maxSize = 0;
    for (size_t i = 0; i < mbr.messageCount; ++i) {
        uint32_t currentSize = mbr.messageInfos[i].size.total;
        if (currentSize > maxSize)
            maxSize = currentSize;
    }
    return maxSize;
}

static void initMaps(void) {
    mbr.nameKeyMap = kh_init(mStr);
    mbr.hashKeyMap = kh_init(m32);
}

static int fillNameMap(void) {
    for (size_t i = 0; i < mbr.messageCount; i++) {
        const nadam_messageInfo_t *mi = mbr.messageInfos + i;
        int ret;
        khiter_t k = kh_put(mStr, mbr.nameKeyMap, mi->name, &ret);
        assert(ret != -1);

        bool keyWasPresent = !ret;
        if (keyWasPresent) {
            errno = NADAM_ERROR_NAME_COLLISION;
            return -1;
        }

        kh_val(mbr.nameKeyMap, k) = i;
    }

    return 0;
}

// unittest
// -----------------------------------------------------------------------------
#ifdef UNITTEST
// nadam_init
int initWithPlausibleArgs(void) {
    nadam_messageInfo_t infos[] = { { .name = "foo", .nameLength = 3 }, 
        { .name = "funhun", .nameLength = 6 } };
    errno = 0;
    ASSERT(!nadam_init(infos, 2, 4));
    ASSERT(!errno);
    return 0;
}

int initWithEmptyMessageInfos(void) {
    errno = 0;
    ASSERT(nadam_init(NULL, 0, 4));
    ASSERT(errno == NADAM_ERROR_EMPTY_MESSAGE_INFOS);
    return 0;
}

int initWithWrongHashLength(void) {
    nadam_messageInfo_t info = { .name = "foo", .nameLength = 3 };
    errno = 0;
    ASSERT(nadam_init(&info, 1, 0));
    ASSERT(errno == NADAM_ERROR_MIN_HASH_LENGTH);
    errno = 0;
    ASSERT(nadam_init(&info, 1, 9));
    ASSERT(errno == NADAM_ERROR_MIN_HASH_LENGTH);
    return 0;
}

int initWithDuplicateName(void) {
    nadam_messageInfo_t infos[] = { { .name = "foo", .nameLength = 3 }, 
        { .name = "foo", .nameLength = 3 } };
    errno = 0;
    ASSERT(nadam_init(infos, 2, 4));
    ASSERT(errno == NADAM_ERROR_NAME_COLLISION);
    return 0;
}

// allocate
int tryToAllocateSmallAmountOfMemory(void) {
    void *mem = NULL;
    int error = allocate(&mem, 42);
    free(mem);

    ASSERT(!error);
    ASSERT(mem);

    return 0;
}
#endif
