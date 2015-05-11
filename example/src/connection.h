#include <stdint.h>
#include <stdbool.h>

void conn_mkfifo(void);
void conn_rmfifo(void);

void conn_open(bool isProcessA);
void conn_close(void);

int conn_send(const void *src, uint32_t n);
int conn_recv(void *dest, uint32_t n);
