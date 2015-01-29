import std.stdio, std.file, std.regex;

void main(string[] args)
{
	auto testInput = readText("test_input/parser");

	enum stringsAndCommentsPattern = "(\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\")|(/\\*[^\\*/]*\\*/|//.*$)";
	auto ctr = ctRegex!(stringsAndCommentsPattern, "m");

	writeln("input:\n", testInput);

	writeln("parsed:");
	foreach (c; matchAll(testInput, ctr))
		writeln(c.hit);
}
