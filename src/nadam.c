#include "nadam.h"

#include <errno.h>
#include <assert.h>

#include "khash.h"

#include "unittestMacros.h"

KHASH_MAP_INIT_INT(m32, size_t)
KHASH_MAP_INIT_STR(mStr, size_t)

struct nadamMember {
    khash_t(mStr) *nameKeyMap;
    khash_t(m32) *hashKeyMap;

    const nadam_messageInfo_t *messageInfos;
    size_t messageCount;
    size_t hashLength;
};

// private declarations
// -----------------------------------------------------------------------------
static int testInitIn(size_t infoCount, size_t hashLengthMin);
static void initMaps(void);
static void destroyMaps(void);
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

    destroyMaps();
    initMaps();

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

    /* For initial implementation let's assume that
       all hashes can be uniquely distinguished by the first 4 bytes
       TODO extension for lengths (4,8] with uint64_t keys  */
    if (hashLengthMin == 0 || hashLengthMin > 4) {
        errno = NADAM_ERROR_HASH_LENGTH_MIN;
        return -1;
    }

    return 0;
}

static void initMaps(void) {
    nadam.nameKeyMap = kh_init(mStr);
    nadam.hashKeyMap = kh_init(m32);
}

static void destroyMaps(void) {
    kh_destroy(mStr, nadam.nameKeyMap);
    nadam.nameKeyMap = NULL;
    kh_destroy(m32, nadam.hashKeyMap);
    nadam.hashKeyMap = NULL;
}

static int fillNameMap(void) {
    for (size_t i = 0; i < nadam.messageCount; i++) {
        const nadam_messageInfo_t *mi = nadam.messageInfos + i;
        int ret;
        khiter_t k = kh_put(mStr, nadam.nameKeyMap, mi->name, &ret);
        assert(ret != -1);

        bool keyWasPresent = !ret;
        if (keyWasPresent) {
            errno = NADAM_ERROR_NAME_COLLISION;
            return -1;
        }

        kh_val(nadam.nameKeyMap, k) = i;
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
    ASSERT(errno == NADAM_ERROR_HASH_LENGTH_MIN);
    errno = 0;
    ASSERT(nadam_init(&info, 1, 9));
    ASSERT(errno == NADAM_ERROR_HASH_LENGTH_MIN);
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

#endif
