## Namdam - Named Data Messaging
### About
Namdam is a definition rather than a library. Any tranmitted message has to be known to both communicating sides.
Not every participant needs to be aware of all existing message types. A 1:n server:clients arrangement is possible,
where a client would communicate using only a subset of available messages.

An Implementation requires following data about a type:
```d
struct NamdamMessage
{
	string name; // arbitrary UTF-8 string
	bool isVariableLength;
	uint length; // represents maximum length, if isVariableLength is true
}
```

Truncated SHA-1 digest of this struct is the type's name used by the protocol for transmission.
If additional salt is used, every participant needs to know it.

An Attempt to use unknown message name or incorrect length might terminate a connection.

### Interface
Hooking-up Namdam reference implementation to an underlying transmission method requieres 2 functions.
```d
void send(in ubyte[] buf);
ubyte[] recv(uint len);
```
C equivalent
```c
int send(const void* buf, uint32_t len);
int recv(void* buf, uint32_t len);
```
Interface is expected to block until exactly len is trasmitted.
If an underlying function is prevented from sending/receiving len bytes
(connection closed; error encountered), interface function should throw an exception or return a non 0 error code.

### Protocol
The protocol just describes, how to send named data. It doesn't care about message subscriptions, updates or write privileges - 
that's up to a particular implementation. One way to handle such advanced logic would be to agree on a pragma-message containing metadata.
That metadata (e.g. XML) would describe subscriptions, privileges, what have you.

Alright, here it goes. After the connection is initiated/handed over, both sides send a single byte.
This byte is a number between 1 and 20. It represents what a participant thinks is the
shortest common collision-free message name length. Bigger number wins. From now on, every transfer is
preceded by that number of bytes, identifying the type.

In a fixed length type, binary data follows the id directly.
Id of a variable length type is followed by 4 bytes. Those represent the length of the data.

TODO example of pragma messages

### Type generator utility
Type generator program should aleviate the need to implement own message type generator for every language.

For C/C++ it creates a simple interface that allowes to iterate through generated types. Queried type would look
something like this:
```c
struct MessageType
{
	uint8_t sha[20];
	bool isVariableSize;
	uint32_t size;
};

struct NamedMessageType
{
	const char* name;
	size_t nameLength;
	struct MessageType type;
};
```
Types should be connected to their names using a hash map for faster lookup. Hash calculations could be cached.

Input to the generator is simpe text describing the types:
```c
/* C style comments */
{ // every type must be enclosed in brackets
"foo"
size = 42 // fixed size message
}

{
"\"bar\" is also a valid name" // C style escapes
size_max = 42 // variable size message
}

{size=3"whitespaces and position shouldn't really matter"}

// { "foo" size = 42 } // name repeated - this would caused an error
/*
An exact duplicate could have been ignored, but for simplicity and
because repeated name might indicate a problem, it results in an error
*/
```
