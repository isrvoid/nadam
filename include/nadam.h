/*
Copyright:  Copyright Johannes Teichrieb 2015
License:    opensource.org/licenses/MIT
*/
#pragma once

#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct {
    bool isVariable;
    union {
        uint32_t total;
        uint32_t max;
    };
} nadam_messageSize_t;

typedef struct {
    const char *name;
    size_t nameLength;
    nadam_messageSize_t size;
    uint8_t hash[20];
} nadam_messageInfo_t;

// errors returned by interface functions
#define NADAM_ERROR_UNKNOWN_NAME 300
#define NADAM_ERROR_EMPTY_MESSAGE_INFOS 301
#define NADAM_ERROR_MIN_HASH_LENGTH 302
#define NADAM_ERROR_NAME_COLLISION 303
#define NADAM_ERROR_ALLOC_FAILED 304
#define NADAM_ERROR_HANDSHAKE_HASH_LENGTH 305
#define NADAM_ERROR_DELEGATE_BUFFER 306
// errors passed to the error delegate
#define NADAM_ERROR_CONNECTION_CLOSED 500
#define NADAM_ERROR_UNKNOWN_HASH 501
#define NADAM_ERROR_VARIABLE_SIZE 502

typedef int (*nadam_send_t)(const void *src, uint32_t n);
typedef int (*nadam_recv_t)(void *dest, uint32_t n);
/* After recvDelegate returns, memory pointed to by msg should be considered invalid
   unless own buffer was provided with nadam_setDelegateWithRecvBuffer().
   Size parmeter will provide the actual size of a variable size message.  */
typedef void (*nadam_recvDelegate_t)(void *msg, uint32_t size, const nadam_messageInfo_t *messageInfo);

// if the error delegate gets called, no new messages will be received (the connection should be closed)
// errno won't be overwritten (check error argument instead)
typedef void (*nadam_errorDelegate_t)(int error);

/* Functions return 0 on success and -1 on error.
   If -1 is returned, errno will contain the specific value.  */
  
/* Modern languages shouldn't care about a string being zero terminated.
   To make C implementation fully compliant, one would need to pass the length with every name.
   That would be painful, therefore the follwing compromise was made:
   name's length is assumed to be the index of first '\0'.
   The limitation of this is that all names truncated at first '\0' have to be unique.
   nadam_init() will test for it. Barring that, messageInfos argument is expected to be correct.
   Otherwise, the behaviour is undefined.
  
   nameLength in nadam_messageInfo_t is endowed
   by message info generator utility, but is ignored in this implementation.  */

// messageInfos will be used continuously - it should be unlimited lifetime const
int nadam_init(const nadam_messageInfo_t *messageInfos, size_t messageInfoCount, size_t hashLengthMin);

/* If the delegate for a message type is not set, messages of this type are ignored (dumped).
   To delete a delegate, pass NULL.  */
/* The simplier interface version uses a shared "stock" buffer to receive messages.
   This buffer can be overwritten at any time after a delegate returns.  */
int nadam_setDelegate(const char *msgName, nadam_recvDelegate_t delegate);
int nadam_setDelegateWithRecvBuffer(const char *msgName, nadam_recvDelegate_t delegate,
        void *buffer, volatile bool *recvStart);

int nadam_initiate(nadam_send_t send, nadam_recv_t recv, nadam_errorDelegate_t errorDelegate);

// size argument is ignored for constant size messages
int nadam_send(const char *name, const void *msg, uint32_t size);
/* Calling this send version (Send With Immutable Name) promises
   that the name is a string literal or memory,
   whose content won't change throughout the life of the program - allows name lookup caching.  */
int nadam_sendWin(const char *name, const void *msg, uint32_t size);

void nadam_stop(void);
