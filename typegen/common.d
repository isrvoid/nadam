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

// TODO add function attributes
class RegexMatchMarshaler(T)
    if (is(typeof(T.init.front) == Captures!string))
{
    private string input;
    private T m;

    this(T m, string input = "")
    {
        this.input = input;
        this.m = m;
    }

    public MessageIdSource[] getSources()
    {
        MessageIdSource[] result;

        return null; //FIXME
    }

    private MessageIdSource getNextSource()
    {
        auto name = getName();
        if (name == null)
            return MessageIdSource.init;

        auto size = getSize();

        return MessageIdSource(name, size);
    }

    // TODO refactor duplicate get function's code
    private string getName()
    {
        forwardToNextElement!false();
        if (m.empty)
            return null;

        auto name = m.front["name"];
        if (name == null)
            // also thrown if name is empty `` - fine for now
            throw new UnexpectedElementException(input, m.hit, "name");

        m.popFront();
        return name;
    }

    private MessageSize getSize()
    {
        import std.conv : to;

        // size keyword
        forwardToNextElement();

        auto sizeKeyword = m.front["sizeKeyword"];
        if (sizeKeyword == null)
            throw new UnexpectedElementException(input, m.hit, "size or size_max keyword");

        m.popFront();

        // equals sign
        forwardToNextElement();

        if (m.hit != "=")
            throw new UnexpectedElementException(input, m.hit, "equals sign");

        m.popFront();

        // size value
        forwardToNextElement();

        auto sizeElement = m.front["digit"];
        if (sizeElement == null)
            throw new UnexpectedElementException(input, m.hit, "size value");

        m.popFront();
        uint size = to!uint(sizeElement);

        // result
        bool isVariableSize = (sizeKeyword == "size_max");
        return MessageSize(size, isVariableSize);
    }

    private void forwardToNextElement(bool throwAtInputsEnd = true)()
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
            throw new UndefinedTokenException(input, m.front["undefined"]);
    }

    // only for unittest
    @property private typeof(T.init.front) front()
    {
        return m.front;
    }

    @property private typeof(T.init.empty) empty()
    {
        return m.empty;
    }
}

public MessageIdSource[] parse(string commonTypeMessageIds)
{
    auto m = matchAll(commonTypeMessageIds, parserRegex);
    auto marshaler = new RegexMatchMarshaler!(typeof(m))(m, commonTypeMessageIds);

    //return mrm.parseAll();
    return null; // FIXME
}

// parse
unittest
{
    auto comment = "// the quick brown fox";

    auto idSources = parse(comment);
    assert(idSources == null);
}
// FIXME add parse tests

// getNextSource
unittest
{
    auto commentsOnly = "// the quick brown fox\n/* jumps over the lazy dog */";
    auto m = matchAll(commentsOnly, parserRegex);

    auto marshaler = new RegexMatchMarshaler!(typeof(m))(m);
    assert(marshaler.getNextSource() == MessageIdSource.init);
}

unittest
{
    auto single = "`foo`\nsize = 3";
    auto m = matchAll(single, parserRegex);

    auto marshaler = new RegexMatchMarshaler!(typeof(m))(m);
    assert(marshaler.getNextSource() == MessageIdSource("foo", MessageSize(3)));
}

unittest
{
    auto singleVariableSize = "`bar` size_max=42";
    auto m = matchAll(singleVariableSize, parserRegex);

    auto marshaler = new RegexMatchMarshaler!(typeof(m))(m);
    assert(marshaler.getNextSource() == MessageIdSource("bar", MessageSize(42, true)));
}

unittest
{
    auto sequence = "// comment\n`fun`size // comment\n= 3\n
        /* comment */ `gun`\nsize_max=\n /* comment */ 7";
    auto m = matchAll(sequence, parserRegex);

    auto marshaler = new RegexMatchMarshaler!(typeof(m))(m);
    assert(marshaler.getNextSource() == MessageIdSource("fun", MessageSize(3)));
    assert(marshaler.getNextSource() == MessageIdSource("gun", MessageSize(7, true)));
    assert(marshaler.empty);
}

unittest
{
    auto negativeSize = "`fun` size = -8";
    auto m = matchAll(negativeSize, parserRegex);

    auto marshaler = new RegexMatchMarshaler!(typeof(m))(m, negativeSize);
    bool caughtException;
    try
    {
        marshaler.getNextSource();
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
    auto nameAfterComments = " // comment\n/* comment */ `foo`";
    auto m = matchAll(nameAfterComments, parserRegex);

    auto marshaler = new RegexMatchMarshaler!(typeof(m))(m);
    marshaler.forwardToNextElement();
    assert(marshaler.front["name"] == "foo");
}

unittest
{
    auto emptyInput = "";
    auto m1 = matchAll(emptyInput, parserRegex);
    auto marshaler1 = new RegexMatchMarshaler!(typeof(m1))(m1);
    marshaler1.forwardToNextElement!false();
    assert(marshaler1.empty);

    auto comment = " /* foo */ ";
    auto m2 = matchAll(comment, parserRegex);
    auto marshaler2 = new RegexMatchMarshaler!(typeof(m2))(m2);
    marshaler2.forwardToNextElement!false();
    assert(marshaler2.empty);

    auto m3 = matchAll(comment, parserRegex);
    auto marshaler3 = new RegexMatchMarshaler!(typeof(m3))(m3, comment);
    bool caughtException;
    try
        marshaler3.forwardToNextElement();
    catch (IncompleteMessageIdException e)
        caughtException = true;
    assert(caughtException);
}

unittest
{
    auto undefinedToken = " // comment\r\n? `foo` size = 123";
    auto m = matchAll(undefinedToken, parserRegex);
    auto marshaler = new RegexMatchMarshaler!(typeof(m))(m, undefinedToken);
    bool caughtException;
    try
        marshaler.forwardToNextElement();
    catch (UndefinedTokenException e)
        caughtException = true;
    assert(caughtException);
}

