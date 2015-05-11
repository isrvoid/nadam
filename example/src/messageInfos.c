#define NADAM_MESSAGE_INFO_COUNT 2
#define NADAM_MIN_HASH_LENGTH 2

static const nadam_messageInfo_t nadamMessageInfos[] = {
    { .name = "ping", .size = { true, { 100 } }, .hash = "pi" },
    { .name = "pong", .size = { true, { 100 } }, .hash = "po" }
};
