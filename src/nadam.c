#include "nadam.h"

// private declarations
// -----------------------------------------------------------------------------

// interface functions
// -----------------------------------------------------------------------------
int nadam_init(const nadam_messageInfo_t *messageInfos, size_t infoCount, size_t hashLengthMin) {
}

int nadam_setDelegate(const char *name, nadam_recvDelegate_t delegate) {
}

int nadam_initiate(nadam_send_t send, nadam_recv_t recv, nadam_errorDelegate_t errorDelegate) {
}

int nadam_send(const char *name, const void *msg, uint32_t size) {
}

int nadam_sendWin(const char *name, const void *msg, uint32_t size) {
    return nadam_send(name, msg, size); // TODO caching
}

void nadam_stop(void) {
}

// private functions
// -----------------------------------------------------------------------------
