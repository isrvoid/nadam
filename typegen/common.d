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
    auto sizeKeywordPattern = "(?P<sizeKeyword>size|size_max)";
    auto equalsSignPattern = "=";
    auto digitPattern = `(?P<value>\d+)`;
    auto undefinedTokenPattern = `(?P<undefined>\S+?)`;

    auto parsingPattern = commentPattern ~ '|' ~ namePattern ~ '|' ~ sizeKeywordPattern ~ '|' ~
        equalsSignPattern ~ '|' ~ digitPattern ~ '|' ~ undefinedTokenPattern;
}

    auto parsingRegex = ctRegex!(parsingPattern, "m");

void main(string[] args)
{
}

void forwardToNextNonComment(T)(ref T m)
    if (is(typeof(m.front) == Captures!string))
{
    while (!m.empty && m.front["comment"] != null)
        m.popFront();
}

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
