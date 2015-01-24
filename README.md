# Namdam
### Named Data Messaging
Namdam is a definition rather than a library. Any tranmitted message has to be known to both communicating sides.
Not every participant needs to be aware of all existing message types. A 1:n server:clients arrangement is possible,
where a client would communicate using only a subset of available messages.

An Implementation requires following data about a type:
struct NamdamMessage
{
	string name; // arbitrary UTF-8 string
	bool isVariableLength;
	uint length; // represents maximum length, if isVariableLength is true
}

Truncated SHA-1 digest of this struct is the type's name used by the protocol for transmission.
If additional salt is used, every participant needs to know it.

An Attempt to use unknown message name or incorrect length might terminate a connection.
