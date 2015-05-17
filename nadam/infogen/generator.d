/*
Copyright:  Copyright Johannes Teichrieb 2015
License:    opensource.org/licenses/MIT
*/
module nadam.infogen.generator;

import std.array : Appender;
import std.stdio : writeln;

import nadam.types;

void main(string args[])
{
    import std.file : read, write;

    version (unittest)
        return 0;

    auto parsedArgs = ArgumentParser(args[1 .. $]);
    if (!parsedArgs.errors.empty)
    {
        foreach (error; parsedArgs.errors)
            writeln("gendsu: error: ", error);

        return -1;
    }
}

// copied from gendsu - TODO refactor and move to util
// TODO add target language switch
struct ArgumentParser
{
    private Appender!(string[]) fileApp;
    private enum outputFileSwitch = "-of";
    private enum 

    string[] errors;

    string outputFile = "messageInfos.c";

    @disable this();

    this(string[] args) pure nothrow @safe
    {
        foreach (arg; args)
        {
            bool isFile = (arg[0] != '-');
            if (isFile)
                fileApp.put(arg);
            else
                handleSwitch(arg);
        }

        if (files.empty)
            errors ~= "no input files";
    }

    @property string[] files() pure nothrow @safe
    {
        return fileApp.data;
    }

    private:

    void handleSwitch(string arg) pure nothrow @safe
    {
        import std.algorithm : startsWith;

        if (arg.startsWith(outputFileSwitch))
            handleOutputFileSwitch(arg);
        else
            errors ~= "unrecognized switch '" ~ arg ~ "'";
    }

    void handleOutputFileSwitch(string arg) pure nothrow @safe
    {
        auto outputFile = arg[outputFileSwitch.length .. $];
        if (outputFile.empty)
        {
            errors ~= "argument expected for switch '" ~ outputFileSwitch ~ "'";
            return;
        }

        this.outputFile = outputFile;
    }
}

// FIXME PluginMaker doesn't merge message info lists,
// it creates a plugin file from a single MessageIdentity list.
struct PluginMaker
{
    private:
    Appender!(Func[]) funcApp;
    Appender!string pluginApp;

    struct Func
    {
        string name;
        string file;
    }

    public void putFunc(string[] names, string file) pure nothrow @safe
    {
        foreach (name; names)
            funcApp.put(Func(name, file));
    }

    public string makePlugin() pure nothrow @safe
    {
        import std.conv : text;

        pluginApp = pluginApp.init;

        putFunctionDeclarations();
        newline();

        putFunctionArray();

        return plugin;
    }

    public string plugin() pure nothrow @safe
    {
        return pluginApp.data;
    }

    {
        putLine("static const _unittest_func_t _unittest_functions[] = {");

        putFunctionLiterals();
        newline();

        pluginApp.put("};");
    }

    void putFunctionLiterals() pure nothrow @safe
    {
        enum softLineWidth = 100;
        enum syntaxOverheadLength = `{,"()",""},`.length;
        enum lineIndent = "    ";

        auto lineLength = lineIndent.length;

        void startNewLine() pure nothrow @safe
        {
            newline();
            pluginApp.put(lineIndent);
            lineLength = lineIndent.length;
        }

        pluginApp.put(lineIndent);

        foreach (func; functions)
        {
            if (lineLength > softLineWidth)
                startNewLine();

            pluginApp.put("{");
            pluginApp.put(func.name);
            pluginApp.put(`,"`);
            pluginApp.put(func.name);
            pluginApp.put(`()","`);
            pluginApp.put(func.file);
            pluginApp.put(`"},`);

            lineLength += func.name.length * 2 + func.file.length + syntaxOverheadLength;
        }
    }

    void putLine(string s) pure nothrow @safe
    {
        pluginApp.put(s);
        newline();
    }

    void newline() pure nothrow @safe
    {
        pluginApp.put("\n");
    }

    Func[] functions() pure nothrow @safe
    {
        return funcApp.data;
    }
}

// unittest
// -----------------------------------------------------------------------------

