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

immutable
{
    auto commentPattern = `(?P<comment>/\*[^\*/]*\*/|//.*$)`;
    auto namePattern = "`(?P<name>[^`]+)`";
    auto sizeKeywordPattern = "(?P<sizeKeyword>size|size_max)";
    auto equalsSignPattern = "=";
    auto digitPattern = `(?P<value>\d+)`;
    auto undefinedTokenPattern = `(?P<undefined>\S+?)`;

    auto commonTypeParsingPattern =
        commentPattern ~ '|' ~
        namePattern ~ '|' ~
        sizeKeywordPattern ~ '|' ~
        equalsSignPattern ~ '|' ~
        digitPattern ~ '|' ~
        undefinedTokenPattern;
}

auto ctr = ctRegex!(commonTypeParsingPattern, "m");

void main(string[] args)
{
    import std.stdio, std.file;
    auto testInput = readText("typegen/test_input/parser");

    writeln("input:\n", testInput);

    writeln("Undefined tokens:");
    foreach (c; matchAll(testInput, ctr))
    {
        auto hit = c["undefined"];
        if (hit.length > 0)
            write(hit);
    }
    writeln();
}

unittest
{
    //auto commonInputFoo = "
}
