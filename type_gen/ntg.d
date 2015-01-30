import std.stdio, std.file, std.regex;

enum stringsAndCommentsPattern = "(\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\")|(/\\*[^\\*/]*\\*/|//.*$)";
enum opIndexComment = 2;

auto ctr = ctRegex!(stringsAndCommentsPattern, "m");

void main(string[] args)
{
    auto testInput = readText("test_input/parser");

    writeln("input:\n", testInput);
    writeln("comments removed:\n", removeComments(testInput));
}

S removeComments(S : string)(S input) 
{
    return replaceAll!(removeComment)(input, ctr);
}

string removeComment(Captures!(string) m)
{
    bool isCommentMatch = m.opIndex(opIndexComment) != null;
    return isCommentMatch ? "" : m.hit;
}
