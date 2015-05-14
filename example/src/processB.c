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
    sleep(1); // wait for process_a to create fifo
    conn_open(false);
    atexit(conn_close);
}

static void recvDelegate(void *msg, uint32_t n, const nadam_messageInfo_t *mi) {
    char *cmsg = msg;
    cmsg[n] = 0;
    printf("b: received '%s': '%s'\n", mi->name, cmsg);
}

static void errorDelegate(int error) {
    printf("b: error delegate: %d\n", error);
    conn_close();
}

int main(void) {
    handleConnection();

    nadam_init(nadamMessageInfos, NADAM_MESSAGE_INFO_COUNT, NADAM_HASH_LENGTH_MIN);
    nadam_setDelegate("ping", recvDelegate);
    nadam_initiate(conn_send, conn_recv, errorDelegate);

    printf("b: sending 'pong'\n");
    const char *pingMsg = "jumps over the lazy dog";
    nadam_send("pong", pingMsg, (uint32_t) strlen(pingMsg));

    sleep(1);
    nadam_stop();
    exit(EXIT_SUCCESS);
}
