#include "connection.h"

#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#define FIFO_AOBI "temp_fifo_aobi"
#define FIFO_AIBO "temp_fifo_aibo"

static int fdOut;
static int fdIn;

void conn_mkfifo(void) {
    mkfifo(FIFO_AOBI, 0666);
    mkfifo(FIFO_AIBO, 0666);
}

void conn_rmfifo(void) {
    unlink(FIFO_AOBI);
    unlink(FIFO_AIBO);
}

void conn_open(bool isProcessA) {
    if (isProcessA) {
        fdOut = open(FIFO_AOBI, O_WRONLY);
        fdIn = open(FIFO_AIBO, O_RDONLY);
    } else {
        fdIn = open(FIFO_AOBI, O_RDONLY);
        fdOut = open(FIFO_AIBO, O_WRONLY);
    }
}

void conn_close(void) {
    close(fdOut);
    close(fdIn);
}

int conn_send(const void *src, uint32_t n) {
    size_t remaining = n;
    while (remaining) {
        ssize_t written = write(fdOut, src, remaining);
        if (written < 0)
            return -1;

        remaining -= (size_t) written;
    }
    return 0;
}

int conn_recv(void *dest, uint32_t n) {
    size_t remaining = n;
    while (remaining) {
        ssize_t received = read(fdIn, dest, remaining);
        if (received < 0)
            return -1;

        remaining -= (size_t) received;
    }
    return 0;
}
