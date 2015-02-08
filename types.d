module nadam.types;

struct MessageId
{
    ubyte[20] hash;
    MessageSize size;

    this(MessageIdSource source) pure nothrow @safe
    {
        import std.digest.sha;
        SHA1 sha;
        sha.put(cast(immutable(ubyte)[]) source.name);
        sha.put(cast(ubyte) source.size.isVariable);
        uint[1] convSize = [source.size.total];
        sha.put(cast(ubyte[4]) convSize);
        hash = sha.finish();

        size = source.size;
    }

    this(in ubyte[] hash, MessageSize size) pure nothrow @safe
    {
        this.hash = hash;
        this.size = size;
    }
}

struct NamedMessageId
{
    string name;
    MessageId id;

    this(MessageIdSource source) pure nothrow @safe
    {
        name = source.name;
        id = MessageId(source);
    }
}

struct MessageIdSource
{
    string name;
    MessageSize size;

    this(string name, MessageSize size) pure nothrow @safe
    {
        this.name = name;
        this.size = size;
    }
}

struct MessageSize
{
    bool isVariable;
    uint total;
    alias max = total;

    // FIXME this(uint size, bool isVariableSize = false) pure nothrow @safe
    this(bool isVariableSize, uint size) pure nothrow @safe
    {
        isVariable = isVariableSize;
        total = size;
    }
}

