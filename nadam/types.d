/*
Copyright:  Copyright Johannes Teichrieb 2015
License:    opensource.org/licenses/MIT
*/
module nadam.types;

struct MessageInfo
{
    string name;
    MessageSize size;
    ubyte[20] hash;

    this(MessageIdentity id) pure nothrow @safe
    {
        import std.digest.sha;
        name = id.name;
        size = id.size;

        SHA1 sha;
        sha.put(cast(immutable(ubyte)[]) name);
        sha.put(cast(ubyte) size.isVariable);
        uint[1] convSize = [size.total];
        sha.put(cast(ubyte[4]) convSize);
        hash = sha.finish();
    }
}

struct MessageIdentity
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

    this(uint size, bool isVariableSize = false) pure nothrow @safe
    {
        isVariable = isVariableSize;
        total = size;
    }
}

