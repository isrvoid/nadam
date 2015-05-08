/*
Copyright:  Copyright Johannes Teichrieb 2015
License:    opensource.org/licenses/MIT
*/
#include "nadam.h"

#include <pthread.h>
#include <errno.h>
#include <assert.h>

#include "khash.h"

#include "unittestMacros.h"

KHASH_MAP_INIT_INT(m32, size_t)
KHASH_MAP_INIT_STR(mStr, size_t)

/* For initial implementation let's assume that
   all hashes can be uniquely distinguished by the first 4 bytes
   TODO extension for lengths (4,8] with uint64_t keys  */
#define HASH_LENGTH_MAX 4

typedef struct {
    nadam_recvDelegate_t delegate;
    void *buffer;
    volatile bool *recvStart;
} recvDelegateRelated_t;

typedef struct {
    khash_t(mStr) *nameKeyMap;
    khash_t(m32) *hashKeyMap;

    void *commonRecvBuffer;
    recvDelegateRelated_t *delegates;
    bool nullRecvStart;

    const nadam_messageInfo_t *messageInfos;
    size_t messageCount;
    size_t hashLength;

    nadam_send_t send;
    nadam_recv_t recv;

    nadam_errorDelegate_t errorDelegate;
} nadamMembers_t;

// private declarations
// -----------------------------------------------------------------------------
static int testInitIn(size_t infoCount, size_t hashLengthMin);
static void freeMembers(void);
static int allocateMembers(void);
static int allocate(void **dest, size_t size);
static uint32_t getMaxMessageSize(void);
static void initDelegates(void);
static recvDelegateRelated_t getDelegateInit(void);
static void initMaps(void);
static int fillNameMap(void);
static void fillHashMap(void);
static int getIndexForName(const char *name, size_t *index);
static void nullDelegate(void *msg, uint32_t size, const nadam_messageInfo_t *messageInfo);
static int handshakeSendHashLength(void);
static int handshakeHandleHashLengthRecv(void);
static int sendFixedSize(const nadam_messageInfo_t *mi, const void *msg);
static int sendVariableSize(const nadam_messageInfo_t *mi, const void *msg, uint32_t size);
// recv (delegate error reporting)
static int recvWorker(void *arg);
static int getIndexForHash(const uint8_t *hash, size_t *index);
static uint32_t truncateHash(const uint8_t *hash);
static int getMessageSize(const nadam_messageInfo_t *mi, uint32_t *size);

static nadamMembers_t mbr;

// interface functions
// -----------------------------------------------------------------------------
int nadam_init(const nadam_messageInfo_t *messageInfos, size_t messageCount, size_t hashLengthMin) {
    if (testInitIn(messageCount, hashLengthMin))
        return -1;

    freeMembers();
    memset(&mbr, 0, sizeof(nadamMembers_t));

    mbr.messageInfos = messageInfos;
    mbr.messageCount = messageCount;
    mbr.hashLength = hashLengthMin;

    if (allocateMembers())
        return -1;

    initDelegates();
    initMaps();
    return fillNameMap();
}

int nadam_setDelegate(const char *name, nadam_recvDelegate_t delegate) {
    return nadam_setDelegateWithRecvBuffer(name, delegate, mbr.commonRecvBuffer, NULL);
}

int nadam_setDelegateWithRecvBuffer(const char *name, nadam_recvDelegate_t delegate,
        void *buffer, volatile bool *recvStart) {
    size_t index;
    if (getIndexForName(name, &index))
        return -1;

    recvDelegateRelated_t *dp = mbr.delegates + index;

    if (delegate == NULL) {
        *dp = getDelegateInit();
        return 0;
    }

    if (buffer == NULL) {
        errno = NADAM_ERROR_DELEGATE_BUFFER;
        return -1;
    }

    dp->recvStart = recvStart ? recvStart : &mbr.nullRecvStart;
    dp->buffer = buffer;
    dp->delegate = delegate;
    return 0;
}

int nadam_initiate(nadam_send_t send, nadam_recv_t recv, nadam_errorDelegate_t errorDelegate) {
    if (send == NULL || recv == NULL || errorDelegate == NULL) {
        errno = NADAM_ERROR_NULL_POINTER;
        return -1;
    }

    mbr.send = send;
    mbr.recv = recv;
    mbr.errorDelegate = errorDelegate;

    if (handshakeSendHashLength())
        return -1;

    if (handshakeHandleHashLengthRecv())
        return -1;

    fillHashMap();
    // TODO spawn thread

    return 0;
}

int nadam_send(const char *name, const void *msg, uint32_t size) {
    size_t index;
    if (getIndexForName(name, &index))
        return -1;

    const nadam_messageInfo_t *mi = mbr.messageInfos + index;
    bool isFixedSize = !mi->size.isVariable;
    if(isFixedSize)
        return sendFixedSize(mi, msg);
    else
        return sendVariableSize(mi, msg, size);
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

    if (hashLengthMin == 0 || hashLengthMin > HASH_LENGTH_MAX) {
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
    if (*dest == NULL) {
        errno = NADAM_ERROR_ALLOC_FAILED;
        return -1;
    }
    memset(*dest, 0, size);
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

static void initDelegates(void) {
    for (size_t i = 0; i < mbr.messageCount; ++i)
        mbr.delegates[i] = getDelegateInit();
}

static recvDelegateRelated_t getDelegateInit(void) {
    recvDelegateRelated_t init = { .delegate = nullDelegate,
        .buffer = mbr.commonRecvBuffer,
        .recvStart = &mbr.nullRecvStart };
    return init;
}

static void initMaps(void) {
    mbr.nameKeyMap = kh_init(mStr);
    mbr.hashKeyMap = kh_init(m32);
}

static int fillNameMap(void) {
    for (size_t i = 0; i < mbr.messageCount; ++i) {
        int ret;
        khiter_t k = kh_put(mStr, mbr.nameKeyMap, mbr.messageInfos[i].name, &ret);
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

static void fillHashMap(void) {
    for (size_t i = 0; i < mbr.messageCount; ++i) {
        int ret;
        uint32_t hash = truncateHash(mbr.messageInfos[i].hash);
        khiter_t k = kh_put(m32, mbr.hashKeyMap, hash, &ret);
        assert(ret != -1);

        kh_val(mbr.hashKeyMap, k) = i;
    }
}

static int getIndexForName(const char *name, size_t *index) {
    khiter_t k = kh_get(mStr, mbr.nameKeyMap, name);

    bool nameNotFound = (k == kh_end(mbr.nameKeyMap));
    if (nameNotFound) {
        errno = NADAM_ERROR_UNKNOWN_NAME;
        return -1;
    }

    *index = kh_val(mbr.nameKeyMap, k);
    return 0;
}

static void nullDelegate(void *msg, uint32_t size, const nadam_messageInfo_t *messageInfo) { }

static int handshakeSendHashLength(void) {
    const uint8_t hashLength = (uint8_t) mbr.hashLength;
    if (mbr.send(&hashLength, 1)) {
        errno = NADAM_ERROR_HANDSHAKE_SEND;
        return -1;
    }
    return 0;
}

static int handshakeHandleHashLengthRecv(void) {
    uint8_t hashLength;
    if (mbr.recv(&hashLength, 1)) {
        errno = NADAM_ERROR_HANDSHAKE_RECV;
        return -1;
    }

    if (hashLength > HASH_LENGTH_MAX) {
        errno = NADAM_ERROR_HANDSHAKE_HASH_LENGTH;
        return -1;
    }

    if (hashLength > mbr.hashLength)
        mbr.hashLength = hashLength;

    return 0;
}

static int sendFixedSize(const nadam_messageInfo_t *mi, const void *msg) {
    int errorCollector = mbr.send(mi->hash, (uint32_t) mbr.hashLength);
    errorCollector |= mbr.send(msg, mi->size.total);

    if (errorCollector) {
        errno = NADAM_ERROR_SEND;
        return -1;
    }
    return 0;
}

static int sendVariableSize(const nadam_messageInfo_t *mi, const void *msg, uint32_t size) {
    if (size > mi->size.max) {
        errno = NADAM_ERROR_SIZE_ARG;
        return -1;
    }
    int errorCollector = mbr.send(mi->hash, (uint32_t) mbr.hashLength);
    errorCollector |= mbr.send(&size, 4);
    errorCollector |= mbr.send(msg, size);

    if (errorCollector) {
        errno = NADAM_ERROR_SEND;
        return -1;
    }
    return 0;
}

// recv
static int recvWorker(void *arg) {
    uint8_t hash[HASH_LENGTH_MAX];
    while (true) {
        if (mbr.recv(hash, (uint32_t) mbr.hashLength)) {
            mbr.errorDelegate(NADAM_ERROR_RECV);
            return -1;
        }

        size_t index;
        int error = getIndexForHash(hash, &index);
        if (error) {
            mbr.errorDelegate(error);
            return -1;
        }

        const nadam_messageInfo_t *messageInfo = mbr.messageInfos + index;
        uint32_t size;
        error = getMessageSize(messageInfo, &size);
        if (error) {
            mbr.errorDelegate(error);
            return -1;
        }

        const recvDelegateRelated_t *delegate = mbr.delegates + index;
        void *buffer = delegate->buffer;
        *delegate->recvStart = true;
        if (mbr.recv(buffer, size)) {
            mbr.errorDelegate(NADAM_ERROR_RECV);
            return -1;
        }

        delegate->delegate(buffer, size, messageInfo);
    }
}

static int getIndexForHash(const uint8_t *hash, size_t *index) {
    khiter_t k = kh_get(m32, mbr.hashKeyMap, truncateHash(hash));

    bool hashNotFound = (k == kh_end(mbr.hashKeyMap));
    if (hashNotFound)
        return NADAM_ERROR_UNKNOWN_HASH;

    *index = kh_val(mbr.hashKeyMap, k);
    return 0;
}

static uint32_t truncateHash(const uint8_t *hash) {
    uint32_t res = 0;
    memcpy(&res, hash, mbr.hashLength);
    return res;
}

static int getMessageSize(const nadam_messageInfo_t *mi, uint32_t *size) {
    nadam_messageSize_t ms = mi->size;
    uint32_t s;
    if (ms.isVariable) {
        if (mbr.recv(&s, 4))
            return NADAM_ERROR_RECV;

        if (s > ms.max)
            return NADAM_ERROR_VARIABLE_SIZE;
    } else {
        s = ms.total;
    }

    *size = s;
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

// nadam_setDelegateWithRecvBuffer
// and nadam_setDelegate as long as it simply forwards
static void recvDelegateDummy(void *msg, uint32_t size, const nadam_messageInfo_t *mi) { }

int normalSetDelegateUse(void) {
    nadam_messageInfo_t infos[] = { { .name = "ZERO", .nameLength = 4 }, { .name = "ONE", .nameLength = 3 } };
    nadam_init(infos, 2, 4);

    int buffer;
    volatile bool recvStart;
    recvDelegateRelated_t d = { .delegate = recvDelegateDummy, .buffer = &buffer,
        .recvStart = &recvStart };
    ASSERT(!nadam_setDelegateWithRecvBuffer("ONE", d.delegate, d.buffer, d.recvStart));
    recvDelegateRelated_t *verify = &mbr.delegates[1];
    ASSERT(memcmp(&d, verify, sizeof(recvDelegateRelated_t)) == 0);
    return 0;
}

int setDelegateOfUnknownMessageError(void) {
    nadam_messageInfo_t info = { .name = "[+]", .nameLength = 3 };
    nadam_init(&info, 1, 4);

    errno = 0;
    int nonNull;
    ASSERT(nadam_setDelegateWithRecvBuffer("[-]", recvDelegateDummy, &nonNull, NULL));
    ASSERT(errno == NADAM_ERROR_UNKNOWN_NAME);
    return 0;
}

int nullBufferForNonNullDelegateError(void) {
    nadam_messageInfo_t info = { .name = "hi there", .nameLength = 8 };
    nadam_init(&info, 1, 4);

    errno = 0;
    ASSERT(nadam_setDelegateWithRecvBuffer("hi there", recvDelegateDummy, NULL, NULL));
    ASSERT(errno == NADAM_ERROR_DELEGATE_BUFFER);
    return 0;
}

int removingADelegateClearsItsData(void) {
    nadam_messageInfo_t info = { .name = "brown fox", .nameLength = 9 };
    nadam_init(&info, 1, 4);
    recvDelegateRelated_t delegateInit = getDelegateInit();

    recvDelegateRelated_t *delegate = &mbr.delegates[0];
    memset(delegate, 0xA5, sizeof(recvDelegateRelated_t));
    ASSERT(!nadam_setDelegateWithRecvBuffer("brown fox", NULL, NULL, NULL));
    ASSERT(memcmp(delegate, &delegateInit, sizeof(recvDelegateRelated_t)) == 0);
    return 0;
}

int passingNullForDelegatesRecvStartUsesInitValue(void) {
    nadam_messageInfo_t info = { .name = "Scorpio", .nameLength = 7 };
    nadam_init(&info, 1, 4);

    int nonNull;
    ASSERT(!nadam_setDelegateWithRecvBuffer("Scorpio", recvDelegateDummy, &nonNull, NULL));
    ASSERT(mbr.delegates[0].recvStart != NULL);
    return 0;
}

// nadam_send
static struct {
    bool sendWasCalled;
    size_t n;
    uint8_t buf[64];
} sendMockupMbr;

static int sendMockup(const void *src, uint32_t n) {
    assert(sendMockupMbr.n + n <= sizeof(sendMockupMbr.buf));

    sendMockupMbr.sendWasCalled = true;
    memcpy(sendMockupMbr.buf + sendMockupMbr.n, src, n);
    sendMockupMbr.n += n;
    return 0;
}

static int failingSendMockup(const void *src, uint32_t n) {
    return -1;
}

static void fakeSendInitiate(nadam_send_t send) {
    memset(&sendMockupMbr, 0, sizeof(sendMockupMbr));
    mbr.send = send;
    mbr.hashLength = 4;
}
// nadam_send helper - end

int sendFixedSizeMessageBasic(void) {
    nadam_messageInfo_t info = { .name = "Aries", .nameLength = 5,
        .size = { false, { 5 } }, .hash = "Arie" };
    nadam_init(&info, 1, 4);
    fakeSendInitiate(sendMockup);

    const char *msg = "Hello";
    const char *expected = "ArieHello";
    ASSERT(!nadam_send("Aries", msg, 0));
    ASSERT(sendMockupMbr.n == strlen(expected));
    ASSERT(memcmp(sendMockupMbr.buf, expected, sendMockupMbr.n) == 0);
    return 0;
}

int sendVariableSizeMessageBasic(void) {
    nadam_messageInfo_t info = { .name = "Taurus", .nameLength = 6,
        .size = { true, { 2 } }, .hash = "Taur" };
    nadam_init(&info, 1, 4);
    fakeSendInitiate(sendMockup);

    const char *msg = "Hi";
    const uint32_t msgLength = 2;
    const char expected[] = "Taur\x02\x00\x00\x00Hi";
    size_t expectedSize = sizeof(expected) - 1;

    ASSERT(!nadam_send("Taurus", msg, msgLength));
    ASSERT(sendMockupMbr.n == expectedSize);
    ASSERT(memcmp(sendMockupMbr.buf, expected, expectedSize) == 0);
    return 0;
}

int sendUnknownMessageError(void) {
    nadam_messageInfo_t info = { .name = "Gemini", .nameLength = 6,
        .size = { false, { 5 } }, .hash = "Gemi" };
    nadam_init(&info, 1, 4);
    fakeSendInitiate(sendMockup);

    const char *msg = "don't care";
    errno = 0;
    ASSERT(nadam_send("something went wrong", msg, 0));
    ASSERT(errno == NADAM_ERROR_UNKNOWN_NAME);
    ASSERT(!sendMockupMbr.sendWasCalled);
    return 0;
}

int sendCommunicationError(void) {
    nadam_messageInfo_t info = { .name = "Virgo", .nameLength = 5 };
    nadam_init(&info, 1, 4);
    fakeSendInitiate(failingSendMockup);

    const char *msg = "don't care";
    errno = 0;
    ASSERT(nadam_send("Virgo", msg, 0));
    ASSERT(errno == NADAM_ERROR_SEND);
    return 0;
}

int sendVariableSizeExceedingLengthError(void) {
    nadam_messageInfo_t info = { .name = "Libra", .nameLength = 5, .size = { true, { 7 } } };
    nadam_init(&info, 1, 4);
    fakeSendInitiate(sendMockup);

    const char msg[] = "size of this message has somehow swollen";
    const uint32_t msgSize = (uint32_t) sizeof(msg) - 1;
    errno = 0;
    ASSERT(nadam_send("Libra", msg, msgSize));
    ASSERT(errno == NADAM_ERROR_SIZE_ARG);
    ASSERT(!sendMockupMbr.sendWasCalled);
    return 0;
}

// recvWorker
static struct {
    int error;
    size_t n;
    uint8_t buf[64];
    size_t bufIndex;
    uint32_t nRecv;
    uint8_t bufRecv[64];
} recvMockupMbr;

static int recvMockup(void *dest, uint32_t n) {
    if (n > recvMockupMbr.n)
        return -1;

    memcpy(dest, recvMockupMbr.buf + recvMockupMbr.bufIndex, n);
    recvMockupMbr.n -= n;
    recvMockupMbr.bufIndex += n;
    return 0;
}

static void errorDelegateMockup(int error) {
    recvMockupMbr.error = error;
}

static void fakeRecvInitiate(const void *recvContent, size_t n) {
    assert(n <= sizeof(recvMockupMbr.buf));

    memset(&recvMockupMbr, 0, sizeof(recvMockupMbr));
    memcpy(recvMockupMbr.buf, recvContent, n);
    recvMockupMbr.n = n;

    mbr.recv = recvMockup;
    mbr.errorDelegate = errorDelegateMockup;
    mbr.hashLength = 4;

    fillHashMap();
    int error = recvWorker(NULL);
    assert(error == -1);
}

static void recvDelegateMockup(void *msg, uint32_t size, const nadam_messageInfo_t *mi) {
    memcpy(recvMockupMbr.bufRecv, msg, size);
    recvMockupMbr.nRecv = size;
}

// recvWorker helper - end
// TODO tests - including variable length error
int recvFixedSizeMessageBasic(void) {
    nadam_messageInfo_t info = { .name = "Sagittarius", .nameLength = 11, .size = { false, { 5 } },
        .hash = "Sagi" };
    nadam_init(&info, 1, 4);
    nadam_setDelegate("Sagittarius", recvDelegateMockup);

    const char *recvContent = "Sagi54321";
    const char *expected = "54321";
    size_t expectedSize = strlen(expected);
    fakeRecvInitiate(recvContent, strlen(recvContent));

    ASSERT(recvMockupMbr.error == NADAM_ERROR_RECV);
    ASSERT(recvMockupMbr.nRecv == expectedSize);
    ASSERT(memcmp(recvMockupMbr.bufRecv, expected, expectedSize) == 0);
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

// getIndexForName
int getIndexForExistingName(void) {
    nadam_messageInfo_t infos[] = { { .name = "the", .nameLength = 3 }, { .name = "quick", .nameLength = 5 },
        { .name = "brown", .nameLength = 5 }, { .name = "fox", .nameLength = 3 } };

    nadam_init(infos, 4, 4);
    for (int i = 3; i >= 0; --i) {
        size_t index;
        ASSERT(!getIndexForName(infos[i].name, &index));
        ASSERT(index == (size_t) i);
    }
    return 0;
}

int tryGettingIndexForUnknownName(void) {
    nadam_messageInfo_t infos[] = { { .name = "foo", .nameLength = 3 }, { .name = "bar", .nameLength = 3 } };

    nadam_init(infos, 2, 4);
    size_t index;
    errno = 0;
    ASSERT(getIndexForName("fun", &index));
    ASSERT(errno == NADAM_ERROR_UNKNOWN_NAME);
    return 0;
}
#endif
