#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "nadam.h"
#include "connection.h"

#include "messageInfos.c"

static void handleConnection(void);
static void recvDelegate(void *msg, uint32_t n, const nadam_messageInfo_t *mi);
static void errorDelegate(int error);

static void handleConnection(void) {
    conn_mkfifo();
    atexit(conn_rmfifo);

    conn_open(true);
    atexit(conn_close);
}

static void recvDelegate(void *msg, uint32_t n, const nadam_messageInfo_t *mi) {
    char *cmsg = msg;
    cmsg[n] = 0;
    printf("a: received '%s': '%s'\n", mi->name, cmsg);
}

static void errorDelegate(int error) {
    printf("a: error delegate: %d\n", error);
}

int main(void) {
    handleConnection();

    nadam_init(nadamMessageInfos, NADAM_MESSAGE_INFO_COUNT, NADAM_MIN_HASH_LENGTH);
    nadam_setDelegate("PONG", recvDelegate);
    if (!nadam_initiate(conn_send, conn_recv, errorDelegate))
        printf("a: nadam handshake successful\n");

    const char *pingMsg = "the quick brown fox";
    printf("a: sending 'PING'\n");
    nadam_send("PING", pingMsg, (uint32_t) strlen(pingMsg));
    sleep(2);

    exit(EXIT_SUCCESS);
}
