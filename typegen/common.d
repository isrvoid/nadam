module nadam.typegen.common;

import std.stdio, std.file, std.regex;

immutable {
    auto namePattern = "`(?P<name>[^`]+)`";
    auto commentPattern = `(?P<comment>/\*[^\*/]*\*/|//.*$)`;
    auto openingBracePattern = `(?P<openingBrace>\{)`;
    auto closingBracePattern = `(?P<closingBrace>\})`;
    auto sizePattern = `(?P<size>(?P<kind>size|size_max)\s*=\s*(?P<value>\d+))`;
    auto undefinedTokenPattern = `(?P<undefined>[^\s]+?)`;

    auto compositePattern =
        commentPattern ~ '|' ~
        namePattern ~ '|' ~
        sizePattern ~ '|' ~
        openingBracePattern ~ '|' ~
        closingBracePattern ~ '|' ~
        undefinedTokenPattern;
}

auto ctr = ctRegex!(compositePattern, "m");

void main(string[] args)
{
    auto testInput = readText("typegen/test_input/parser");

    writeln("input:\n", testInput);
    writeln("comments removed:\n", removeComments(testInput));

    writeln("Undefined tokens:");
    foreach (c; matchAll(testInput, ctr))
    {
        auto hit = c["undefined"];
        if (hit.length > 0)
            write(hit);
    }
    writeln();
}

S removeComments(S : string)(S input) 
{
    return replaceAll!(removeComment)(input, ctr);
}

string removeComment(Captures!(string) m)
{
    bool isCommentMatch = m["comment"].length > 0;
    return isCommentMatch ? "" : m.hit;
}

unittest
{
}
