module nadam.typegen.common;

import std.regex;
import std.conv : text;

import nadam.types;

class IncompleteMessageIdException : Exception
{
    this() pure nothrow @safe
    {
        auto msg = "Incomplete message ID at input's end.";
        super(msg);
    }
}

// TODO refactor input string position handling into its own type
class IllegalTokenException : Exception
{
    this(string input, string token) pure nothrow @safe
    {
        size_t tokenPosition = token.ptr - input.ptr;
        string msg = text("Token \"", token, "\" at position ", tokenPosition, " is illegal.");
        super(msg);
    }
}

class UnexpectedElementException : Exception
{
    this(string input, string element, string expected) pure nothrow @safe
    {
        size_t elementPosition = element.ptr - input.ptr;
        string msg = text("Element \"", element, "\" at position ",
                elementPosition, " seems to be out of order. Expected: ", expected);
        super(msg);
    }
}

class RepeatedNameException : Exception
{
    this(string input, string name) pure nothrow @safe
    {
        size_t namePosition = name.ptr - input.ptr;
        string msg = text("Name \"", name, "\" at position ", namePosition, " was previously defined.");
        super(msg);
    }
}

immutable
{
    auto commentPattern = `(?P<comment>/\*[^\*/]*\*/|//.*$)`;
    auto namePattern = "`(?P<name>[^`]+)`";
    auto sizeKeywordPattern = "(?P<sizeKeyword>size_max|size)";
    auto equalsSignPattern = "=";
    auto digitPattern = `(?P<digit>\d+)`;
    auto undefinedTokenPattern = `(?P<undefined>\S+?)`;

    auto parsingPattern = commentPattern ~ '|' ~ namePattern ~ '|' ~ sizeKeywordPattern ~ '|' ~
        equalsSignPattern ~ '|' ~ digitPattern ~ '|' ~ undefinedTokenPattern;
}

    auto parsingRegex = ctRegex!(parsingPattern, "m");

void main(string[] args)
{
}

// FIXME refactor to class, to not pass MatchResult around
// this would also eliminate repeated MatchResult type tests
MessageIdSource getNextSource(T)(ref T m)
    if (is(typeof(m.front) == Captures!string))
{
    auto name = getName(m);
    if (name == null)
        return MessageIdSource.init;

    auto size = getSize(m);

    return MessageIdSource(name, size);
}

// TODO refactor duplicate get function's code
string getName(T)(ref T m)
{
    forwardToNextNonComment(m);
    if (m.empty)
        return null;

    auto name = m.front["name"];
    if (name == null)
        // also thrown if name is empty `` - fine for now
        throw new UnexpectedElementException("", m.hit, "name"); // FIXME input missing

    m.popFront();
    return name;
}

MessageSize getSize(T)(ref T m)
{
    // size keyword
    forwardToNextNonComment(m);
    if (m.empty)
        throw new IncompleteMessageIdException;

    auto sizeKeyword = m.front["sizeKeyword"];
    if (sizeKeyword == null)
        throw new UnexpectedElementException("", m.hit, "size or size_max keyword"); // FIXME input missing

    m.popFront();
    // equals sign
    forwardToNextNonComment(m);
    if (m.empty)
        throw new IncompleteMessageIdException;

    if (m.hit != "=")
        throw new UnexpectedElementException("", m.hit, "equals sign"); // FIXME input missing

    m.popFront();
    // size value
    forwardToNextNonComment(m);
    if (m.empty)
        throw new IncompleteMessageIdException;

    auto sizeElement = m.front["digit"];
    if (sizeElement == null)
        throw new UnexpectedElementException("", m.hit, "size value"); // FIXME input missing

    m.popFront();

    import std.conv : to;
    uint size = to!uint(sizeElement);

    // result
    bool isVariableSize = (sizeKeyword == "size_max");
    return MessageSize(isVariableSize, size);
}
// FIXME replace forwardToNextNonComment with forwardToNextElement(bool throwAtEndOfInput = true)() - ignores comments, throws on ivalid

void forwardToNextNonComment(T)(ref T m)
    if (is(typeof(m.front) == Captures!string))
{
    while (!m.empty && m.front["comment"] != null)
        m.popFront();
}

// getNextSource
unittest
{
    auto commentsOnly = "// the quick brown fox\n/* jumps over the lazy dog */";
    auto m = matchAll(commentsOnly, parsingRegex);

    assert(getNextSource(m) == MessageIdSource.init);
}

unittest
{
    auto single = "`foo`\nsize = 3";
    auto m = matchAll(single, parsingRegex);

    assert(getNextSource(m) == MessageIdSource("foo", MessageSize(false, 3)));
}

unittest
{
    auto singleVariableSize = "`bar` size_max=42";
    auto m = matchAll(singleVariableSize, parsingRegex);

    assert(getNextSource(m) == MessageIdSource("bar", MessageSize(true, 42)));
}

unittest
{
    auto sequence = "// comment\n`fun`size // comment\n= 3\n
        /* comment */ `gun`\nsize_max=\n /* comment */ 7";
    auto m = matchAll(sequence, parsingRegex);

    assert(getNextSource(m) == MessageIdSource("fun", MessageSize(false, 3)));
    assert(getNextSource(m) == MessageIdSource("gun", MessageSize(true, 7)));
    assert(m.empty);
}

unittest
{
    auto negativeSize = "`fun` size = -8";
    auto m = matchAll(negativeSize, parsingRegex);

    bool caughtException;
    try
    {
        getNextSource(m);
    }
    catch (UnexpectedElementException e)
    {
        caughtException = true;
    }

    assert(caughtException);
}

// getSources
// TODO duplicate name

// forwardToNextNonComment
unittest
{
    auto nameAfterComments = " // comment
        /* comment */ `foo`";
    auto m = matchAll(nameAfterComments, parsingRegex);

    forwardToNextNonComment(m);
    assert(m.front["name"] == "foo");
}

unittest
{
    auto emptyInput = "";
    auto m1 = matchAll(emptyInput, parsingRegex);
    forwardToNextNonComment(m1);
    assert(m1.empty);

    auto commentFollowedByEndOfInput = " /* foo */ ";
    auto m2 = matchAll(commentFollowedByEndOfInput, parsingRegex);
    forwardToNextNonComment(m2);
    assert(m2.empty);
}

// FIXME invalid token test
