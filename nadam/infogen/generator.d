/*
Copyright:  Copyright Johannes Teichrieb 2015
License:    opensource.org/licenses/MIT
*/
module nadam.infogen.generator;

import std.range : empty;
import std.array : Appender;
import std.conv : text;
import std.stdio : writeln;

import nadam.types;

int main(string args[])
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

    return 0;
}

// copied from gendsu - TODO refactor and move to util
// TODO add target language switch
struct ArgumentParser
{
    private Appender!(string[]) fileApp;
    private enum outputFileSwitch = "-of";

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

struct InfoMaker
{
    private:
    MessageInfo[] infos;
    Appender!string app;

    @disable this();

    public this(MessageIdentity[] ids) {
        infos = new MessageInfo[ids.length];
        foreach (i, id; ids)
            infos[i] = MessageInfo(id);

        makeInfos();
    }

    public @property string infosResult() pure nothrow @safe
    {
        return app.data;
    }

    auto makeInfos() pure @safe
    {
        app = app.init;

        putInfoCount(infos.length);
        putMinHashLength(getMinHashLength());
        newline();

        putInfoArray();

        return infosResult;
    }

    void putInfoCount(size_t count) pure nothrow @safe
    {
        app.put("#define MESSAGE_INFO_COUNT ");
        putLine(text(count));
    }

    void putMinHashLength(size_t val) pure nothrow @safe
    {
        app.put("#define HASH_LENGTH_MIN ");
        putLine(text(val));
    }

    size_t getMinHashLength() pure nothrow @safe
    {
        return 2; // FIXME
    }

    void putInfoArray() pure @safe
    {
        putLine("static const nadam_messageInfo_t messageInfos[] = {");
        putInfoLiterals();
        putLine("};");
    }

    void putInfoLiterals() pure @safe
    {
        foreach (info; infos)
        {
            app.put(`    `);
            app.put(`{ "`);
            app.put(info.name);
            app.put(`", `);
            app.put(text(info.name.length));
            app.put(`, { `);
            app.put(text(cast(int) info.size.isVariable));
            app.put(`, { `);
            app.put(text(info.size.total));
            app.put(` }, { `);
            app.put(text(info.hash)[1 .. $ - 1]);
            app.put(` } },`);
            newline();
        }
    }

    void putLine(string s) pure nothrow @safe
    {
        app.put(s);
        newline();
    }

    void newline() pure nothrow @safe
    {
        app.put("\n");
    }
}

// unittest
// -----------------------------------------------------------------------------

