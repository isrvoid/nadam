/*
Copyright:  Copyright Johannes Teichrieb 2015
License:    opensource.org/licenses/MIT
*/
module nadam.infogen.parser;

import std.regex;
import std.conv : text;

import nadam.types;

abstract class ParserException : Exception
{
    this(string msg, string file, size_t line, Throwable next) pure nothrow @safe
    {
        super(msg, file, line, next);
    }
}

class IncompleteMessageIdException : ParserException
{
    this(string file = __FILE__, size_t line = __LINE__, Throwable next = null) pure nothrow @safe
    {
        auto msg = "Incomplete message ID at input's end.";
        super(msg, file, line, next);
    }
}

// TODO refactor input string position handling into its own type
class UndefinedTokenException : ParserException
{
    this(string input, string token, string file = __FILE__,
            size_t line = __LINE__, Throwable next = null) pure nothrow @safe
    {
        size_t tokenPosition = token.ptr - input.ptr;
        string msg = text("Token \"", token, "\" at position ", tokenPosition, " is undefined.");
        super(msg, file, line, next);
    }
}

class UnexpectedElementException : ParserException
{
    this(string input, string element, string expected, string file = __FILE__,
            size_t line = __LINE__, Throwable next = null) pure nothrow @safe
    {
        size_t elementPosition = element.ptr - input.ptr;
        string msg = text("Element \"", element, "\" at position ",
                elementPosition, " seems to be out of order. Expected: ", expected);
        super(msg, file, line, next);
    }
}

class RepeatedNameException : ParserException
{
    this(string input, string name, string file = __FILE__,
            size_t line = __LINE__, Throwable next = null) pure nothrow @safe
    {
        size_t namePosition = name.ptr - input.ptr;
        string msg = text("Name \"", name, "\" at position ", namePosition, " was defined previously.");
        super(msg, file, line, next);
    }
}

enum : string
{
    commentPattern = `(?P<comment>/\*.*?\*/|//.*$)`,
    namePattern = "`(?P<name>[^`]+)`",
    sizeKeywordPattern = "(?P<sizeKeyword>size_max|size)",
    equalsSignPattern = "=",
    digitPattern = `(?P<digit>\d+)`,
    undefinedTokenPattern = `(?P<undefined>\S+?)`,

    parserPattern = commentPattern ~ '|' ~ namePattern ~ '|' ~ sizeKeywordPattern ~ '|' ~
        equalsSignPattern ~ '|' ~ digitPattern ~ '|' ~ undefinedTokenPattern
}

static parserRegex = ctRegex!(parserPattern, "m");

// TODO add function attributes
class Parser
{
    this(string input)
    {
        this.input = toParse = input;
        sources = getSources().idup;
    }

    version (unittest)
    {
        this(string input, bool parse)
        {
            this.input = toParse = input;
            if (parse)
                sources = getSources().idup;
        }
    }

    immutable MessageIdentity[] sources;

    private:

    string input, toParse;
    Captures!string front;

    auto getSources()
    {
        auto collector = new SourceCollector;
        MessageIdentity currentSource;
        while ((currentSource = getNextSource()) != MessageIdentity.init)
            collector.put(currentSource);

        return collector.sources;
    }

    auto getNextSource()
    {
        auto name = getName();
        if (name == null)
            return MessageIdentity.init;

        auto size = getSize();

        return MessageIdentity(name, size);
    }

    string getName()
    {
        forwardToNextElement!false();
        if (front.empty)
            return null;

        auto name = front["name"];
        if (name == null)
            // also thrown if name is empty `` - fine for now
            throw new UnexpectedElementException(input, front.hit, "name");

        return name;
    }

    MessageSize getSize()
    {
        auto sizeKeyword = getSizeKeyword();
        findEqualsSign();
        auto sizeValue = getSizeValue();

        bool isVariableSize = (sizeKeyword == "size_max");
        return MessageSize(sizeValue, isVariableSize);
    }

    string getSizeKeyword()
    {
        forwardToNextElement();

        auto sizeKeyword = front["sizeKeyword"];
        if (sizeKeyword == null)
            throw new UnexpectedElementException(input, front.hit, "size or size_max keyword");

        return sizeKeyword;
    }

    void findEqualsSign()
    {
        forwardToNextElement();

        if (front.hit != "=")
            throw new UnexpectedElementException(input, front.hit, "equals sign");
    }

    uint getSizeValue()
    {
        import std.conv : to;

        forwardToNextElement();

        auto sizeElement = front["digit"];
        if (sizeElement == null)
            throw new UnexpectedElementException(input, front.hit, "size value");

        return to!uint(sizeElement);
    }

    void forwardToNextElement(bool throwAtInputsEnd = true)()
    {
        do
        {
            advanceFront();
        } while (!front.empty && front["comment"] != null);

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

    class SourceCollector
    {
        import std.array : Appender;

        void put(MessageIdentity source) @safe
        {
            ensureUniqueName(source.name);
            collector.put(source);
        }

        @property auto sources() pure nothrow @safe
        {
            return collector.data;
        }

        private:
        Appender!(MessageIdentity[]) collector;
        bool[string] repeatedNameGuard;

        void ensureUniqueName(string name) @safe
        {
            if (name in repeatedNameGuard)
                throw new RepeatedNameException(input, name);

            repeatedNameGuard[name] = true;
        }
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

    auto sequence = "/* /* the* / quick */`foo`size// brown fox\r\n =\n
        /* jumpes over */42`bar`\n// the lazy dog\nsize_max=\r\n123";

    auto parser = new Parser(sequence);
    assert(parser.sources.length == 2);
    assert(canFind(parser.sources, MessageIdentity("foo", MessageSize(42))));
    assert(canFind(parser.sources, MessageIdentity("bar", MessageSize(123, true))));
}

unittest
{
    auto incomplete = "`fun` size = 1 `gun` size_max = // missing size";
    bool caughtException;
    try
        auto parser = new Parser(incomplete);
    catch (IncompleteMessageIdException e)
        caughtException = true;

    assert(caughtException);
}

unittest
{
    auto duplicateName = "`foo` size = 42 `foo` size = 42";
    bool caughtException;
    try
        auto parser = new Parser(duplicateName);
    catch (RepeatedNameException e)
        caughtException = true;

    assert(caughtException);
}

// getNextSource
unittest
{
    auto commentsOnly = "/**/// the quick brown fox\n/* jumps over the lazy dog */";
    auto parser = new Parser(commentsOnly, false);

    assert(parser.getNextSource() == MessageIdentity.init);
}

unittest
{
    auto single = "`foo`\nsize = 3";
    auto parser = new Parser(single, false);

    assert(parser.getNextSource() == MessageIdentity("foo", MessageSize(3)));
}

unittest
{
    auto singleVariableSize = "`bar` size_max=42";
    auto parser = new Parser(singleVariableSize, false);

    assert(parser.getNextSource() == MessageIdentity("bar", MessageSize(42, true)));
}

unittest
{
    auto sequence = "// comment\n`fun`size // comment\n= 3\n
        /* comment */ `gun`\nsize_max=\n /* comment */ 7";

    auto parser = new Parser(sequence, false);
    assert(parser.getNextSource() == MessageIdentity("fun", MessageSize(3)));
    assert(parser.getNextSource() == MessageIdentity("gun", MessageSize(7, true)));
    assert(parser.getNextSource() == MessageIdentity.init);
    assert(parser.front.empty);
}

unittest
{
    auto negativeSize = "`fun` size = -8";

    bool caughtException;
    auto parser = new Parser(negativeSize, false);
    try
        parser.getNextSource();
    catch (UndefinedTokenException e)
        caughtException = true;

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

