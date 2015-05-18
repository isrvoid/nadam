#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>

#include "nadam.h"
#include "connection.h"

#include "messageInfos.c"

static void handleConnection(void) {
    sleep(1); // wait for process_a to create fifo
    conn_open(false);
    atexit(conn_close);
}

static void genericStringDelegate(void *msg, uint32_t n, const nadam_messageInfo_t *mi) {
    char *cmsg = msg;
    cmsg[n] = 0;
    printf("b: received '%s': '%s'\n", mi->name, cmsg);
}

static struct {
    double duration;
    uint32_t count;
} storage;

static void countDelegate(void *msg, uint32_t n, const nadam_messageInfo_t *mi) {
    printf("b: received '%s': %u\n", mi->name, storage.count);
}

static void durationDelegate(void *msg, uint32_t n, const nadam_messageInfo_t *mi) {
    printf("b: received '%s': %f\n", mi->name, storage.duration);
}

static void errorDelegate(int error) {
    printf("b: error delegate: %d\n", error);
    conn_close();
}

static void verboseSend(const char *name, const void *msg, uint32_t size) {
    printf("b: sending '%s'\n", name);
    int error = nadam_send(name, msg, size);
    assert(!error);
}

static void initNadam(void) {
    int errorCollector = 0;
    errorCollector |= nadam_init(messageInfos, MESSAGE_INFO_COUNT, HASH_LENGTH_MIN);

    errorCollector |= nadam_setDelegate("ping", genericStringDelegate);
    errorCollector |= nadam_setDelegate("pong", genericStringDelegate);
    errorCollector |= nadam_setDelegateWithRecvBuffer("Foo count", countDelegate, &storage.count, NULL);
    errorCollector |= nadam_setDelegateWithRecvBuffer("Bar.duration", durationDelegate, &storage.duration, NULL);

    errorCollector |= nadam_initiate(conn_send, conn_recv, errorDelegate);

    assert(!errorCollector);
}

int main(void) {
    handleConnection();

    initNadam();

    const char *pingMsg = "jumps over the lazy dog";
    verboseSend("pong", pingMsg, (uint32_t) strlen(pingMsg));

    sleep(1);
    nadam_stop();
    exit(EXIT_SUCCESS);
}
