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
    conn_close();
}

int main(void) {
    handleConnection();

    nadam_init(messageInfos, MESSAGE_INFO_COUNT, HASH_LENGTH_MIN);
    nadam_setDelegate("pong", recvDelegate);
    nadam_initiate(conn_send, conn_recv, errorDelegate);

    printf("a: sending 'ping'\n");
    const char *pingMsg = "the quick brown fox";
    nadam_send("ping", pingMsg, (uint32_t) strlen(pingMsg));

    sleep(1);
    nadam_stop();
    exit(EXIT_SUCCESS);
}
