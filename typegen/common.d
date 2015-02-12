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
        string msg = text("Name \"", name, "\" at position ", namePosition, " was defined previously.");
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
class Parser
{
    version (unittest)
    {
        this(string input, bool parse = true)
        {
            this.input = toParse = input;
            advanceFront();
            if (parse)
                sources = getSources().idup;
        }
    }
    else
    {
        this(string input)
        {
            this.input = toParse = input;
            advanceFront();
            sources = getSources().idup;
        }
    }

    immutable MessageIdSource[] sources;

    private:

    string input, toParse;
    Captures!string front;
    bool[string] repeatedNameGuard;

    MessageIdSource[] getSources()
    {
        MessageIdSource[] sources;
        MessageIdSource currentSource;
        while ((currentSource = getNextSource()) != MessageIdSource.init)
            appendSource(sources, currentSource);

        return sources;
    }

    void appendSource(ref MessageIdSource[] sources, MessageIdSource source)
    {
        if (source.name in repeatedNameGuard)
            throw new RepeatedNameException(input, source.name);

        repeatedNameGuard[source.name] = true;
        sources ~= source;
    }

    MessageIdSource getNextSource()
    {
        auto name = getName();
        if (name == null)
            return MessageIdSource.init;

        auto size = getSize();

        return MessageIdSource(name, size);
    }

    // TODO refactor duplicate get function's code
    string getName()
    {
        forwardToNextElement!false();
        if (front.empty)
            return null;

        auto name = front["name"];
        if (name == null)
            // also thrown if name is empty `` - fine for now
            throw new UnexpectedElementException(input, front.hit, "name");

        advanceFront();
        return name;
    }

    MessageSize getSize()
    {
        import std.conv : to;

        // size keyword
        forwardToNextElement();

        auto sizeKeyword = front["sizeKeyword"];
        if (sizeKeyword == null)
            throw new UnexpectedElementException(input, front.hit, "size or size_max keyword");

        advanceFront();

        // equals sign
        forwardToNextElement();

        if (front.hit != "=")
            throw new UnexpectedElementException(input, front.hit, "equals sign");

        advanceFront();

        // size value
        forwardToNextElement();

        auto sizeElement = front["digit"];
        if (sizeElement == null)
            throw new UnexpectedElementException(input, front.hit, "size value");

        advanceFront();
        uint size = to!uint(sizeElement);

        // result
        bool isVariableSize = (sizeKeyword == "size_max");
        return MessageSize(size, isVariableSize);
    }

    void forwardToNextElement(bool throwAtInputsEnd = true)()
    {
        while (!front.empty && front["comment"] != null)
            advanceFront();

        if (front.empty)
        {
            static if (throwAtInputsEnd)
                throw new IncompleteMessageIdException;
            else
                return;
        }

        if (front["undefined"] != null)
            throw new UndefinedTokenException(input, front["undefined"]);
    }

    void advanceFront() @safe
    {
        front = matchFirst(toParse, parserRegex);
        toParse = front.post;
    }
}

// parser
unittest
{
    auto comment = "// the quick brown fox";
    auto parser = new Parser(comment);

    assert(parser.sources == null);
}

unittest
{
    import std.algorithm;

    auto sequence = "/* the quick */`foo`size// brown fox\r\n =\n
        /* jumpes over */42`bar`\n// the lazy dog\nsize_max=\r\n123";

    auto parser = new Parser(sequence);
    assert(parser.sources.length == 2);
    assert(canFind(parser.sources, MessageIdSource("foo", MessageSize(42))));
    assert(canFind(parser.sources, MessageIdSource("bar", MessageSize(123, true))));
}

unittest
{
    auto incomplete = "`fun` size = 1 `gun` size_max = // missing size";
    bool caughtException;
    try
    {
        auto parser = new Parser(incomplete);
    }
    catch (IncompleteMessageIdException e)
    {
        caughtException = true;
    }
    assert(caughtException);
}

unittest
{
    auto duplicateName = "`foo` size = 42 `foo` size = 42";
    bool caughtException;
    try
    {
        auto parser = new Parser(duplicateName);
    }
    catch (RepeatedNameException e)
    {
        caughtException = true;
    }
    assert(caughtException);
}

// getNextSource
unittest
{
    auto commentsOnly = "// the quick brown fox\n/* jumps over the lazy dog */";
    auto parser = new Parser(commentsOnly, false);

    assert(parser.getNextSource() == MessageIdSource.init);
}

unittest
{
    auto single = "`foo`\nsize = 3";
    auto parser = new Parser(single, false);

    assert(parser.getNextSource() == MessageIdSource("foo", MessageSize(3)));
}

unittest
{
    auto singleVariableSize = "`bar` size_max=42";
    auto parser = new Parser(singleVariableSize, false);

    assert(parser.getNextSource() == MessageIdSource("bar", MessageSize(42, true)));
}

unittest
{
    auto sequence = "// comment\n`fun`size // comment\n= 3\n
        /* comment */ `gun`\nsize_max=\n /* comment */ 7";

    auto parser = new Parser(sequence, false);
    assert(parser.getNextSource() == MessageIdSource("fun", MessageSize(3)));
    assert(parser.getNextSource() == MessageIdSource("gun", MessageSize(7, true)));
    assert(parser.front.empty);
}

unittest
{
    auto negativeSize = "`fun` size = -8";

    bool caughtException;
    auto parser = new Parser(negativeSize, false);
    try
    {
        parser.getNextSource();
    }
    catch (UndefinedTokenException e)
    {
        caughtException = true;
    }

    assert(caughtException);
}


// forwardToNextElement
unittest
{
    auto nameAfterComments = " // comment\n/* comment */ `foo`";
    auto parser = new Parser(nameAfterComments, false);

    parser.forwardToNextElement();
    assert(parser.front["name"] == "foo");
}

unittest
{
    auto emptyInput = "";
    auto parser1 = new Parser(emptyInput, false);
    parser1.forwardToNextElement!false();
    assert(parser1.front.empty);

    auto comment = " /* foo */ ";
    auto parser2 = new Parser(comment, false);
    parser2.forwardToNextElement!false();
    assert(parser2.front.empty);

    auto parser3 = new Parser(comment, false);
    bool caughtException;
    try
        parser3.forwardToNextElement();
    catch (IncompleteMessageIdException e)
        caughtException = true;
    assert(caughtException);
}

unittest
{
    auto undefinedToken = " // comment\r\n? `foo` size = 123";
    auto parser = new Parser(undefinedToken, false);
    bool caughtException;
    try
        parser.forwardToNextElement();
    catch (UndefinedTokenException e)
        caughtException = true;
    assert(caughtException);
}

