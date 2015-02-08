module nadam.typegen.common;

import std.regex;
import std.conv : text;

import nadam.types;

// FIXME forward throw location correctly
class IncompleteMessageIdException : Exception
{
    this() pure nothrow @safe
    {
        auto msg = "Incomplete message ID at input's end.";
        super(msg);
    }
}

// TODO refactor input string position handling into its own type
class UndefinedTokenException : Exception
{
    this(string input, string token) pure nothrow @safe
    {
        size_t tokenPosition = token.ptr - input.ptr;
        string msg = text("Token \"", token, "\" at position ", tokenPosition, " is undefined.");
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

    auto parserPattern = commentPattern ~ '|' ~ namePattern ~ '|' ~ sizeKeywordPattern ~ '|' ~
        equalsSignPattern ~ '|' ~ digitPattern ~ '|' ~ undefinedTokenPattern;
}

auto parserRegex = ctRegex!(parserPattern, "m");

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
    forwardToNextElement!false(m);
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
    forwardToNextElement(m);

    auto sizeKeyword = m.front["sizeKeyword"];
    if (sizeKeyword == null)
        throw new UnexpectedElementException("", m.hit, "size or size_max keyword"); // FIXME input missing

    m.popFront();
    // equals sign
    forwardToNextElement(m);

    if (m.hit != "=")
        throw new UnexpectedElementException("", m.hit, "equals sign"); // FIXME input missing

    m.popFront();
    // size value
    forwardToNextElement(m);

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

void forwardToNextElement(bool throwAtInputsEnd = true, T)(ref T m)
    if (is(typeof(m.front) == Captures!string))
{
    while (!m.empty && m.front["comment"] != null)
        m.popFront();

    if (m.empty)
    {
        static if (throwAtInputsEnd)
            throw new IncompleteMessageIdException;
        else
            return;
    }

    if (m.front["undefined"] != null)
        throw new UndefinedTokenException("", m.front["undefined"]);
}

// getNextSource
unittest
{
    auto commentsOnly = "// the quick brown fox\n/* jumps over the lazy dog */";
    auto m = matchAll(commentsOnly, parserRegex);

    assert(getNextSource(m) == MessageIdSource.init);
}

unittest
{
    auto single = "`foo`\nsize = 3";
    auto m = matchAll(single, parserRegex);

    assert(getNextSource(m) == MessageIdSource("foo", MessageSize(false, 3)));
}

unittest
{
    auto singleVariableSize = "`bar` size_max=42";
    auto m = matchAll(singleVariableSize, parserRegex);

    assert(getNextSource(m) == MessageIdSource("bar", MessageSize(true, 42)));
}

unittest
{
    auto sequence = "// comment\n`fun`size // comment\n= 3\n
        /* comment */ `gun`\nsize_max=\n /* comment */ 7";
    auto m = matchAll(sequence, parserRegex);

    assert(getNextSource(m) == MessageIdSource("fun", MessageSize(false, 3)));
    assert(getNextSource(m) == MessageIdSource("gun", MessageSize(true, 7)));
    assert(m.empty);
}

unittest
{
    auto negativeSize = "`fun` size = -8";
    auto m = matchAll(negativeSize, parserRegex);

    bool caughtException;
    try
    {
        getNextSource(m);
    }
    catch (UndefinedTokenException e)
    {
        caughtException = true;
    }

    assert(caughtException);
}

// getSources
// TODO duplicate name

// forwardToNextElement
unittest
{
    auto nameAfterComments = " // comment
        /* comment */ `foo`";
    auto m = matchAll(nameAfterComments, parserRegex);

    forwardToNextElement!false(m);
    assert(m.front["name"] == "foo");
}

unittest
{
    auto emptyInput = "";
    auto m1 = matchAll(emptyInput, parserRegex);
    forwardToNextElement!false(m1);
    assert(m1.empty);

    auto comment = " /* foo */ ";
    auto m2 = matchAll(comment, parserRegex);
    forwardToNextElement!false(m2);
    assert(m2.empty);

    auto m3 = matchAll(comment, parserRegex);
    bool caughtException;
    try
        forwardToNextElement(m3);
    catch (IncompleteMessageIdException e)
        caughtException = true;
    assert(caughtException);
}

unittest
{
    auto undefinedToken = " // comment\r\n? `foo` size = 123";
    auto m = matchAll(undefinedToken, parserRegex);
    bool caughtException;
    try
        forwardToNextElement(m);
    catch (UndefinedTokenException e)
        caughtException = true;
    assert(caughtException);
}

