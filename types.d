module nadam.types;

struct MessageId
{
    ubyte[20] hash;
    MessageSize size;
}

struct NamedMessageId
{
    string name;
    MessageId id;
}

struct MessageIdSource
{
    struct name;
    MessageSize size;
}

struct MessageSize
{
    bool isVariable;
    uint total;
    alias max = total;
}

