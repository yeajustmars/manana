package manana;

import manana.lexer.Lexer;
import manana.parser.Parser;
import manana.codegen.HtmlCompiler;

class TestHtmlCompiler {
    public function new() {}

    public function runAll():Void {
        Sys.println("Running TestHtmlCompiler...");
        testSimpleElementRendering();
        testVoidTagRendering();
        testContextInterpolation();
        testViewComposition();
    }

    function testSimpleElementRendering():Void {
        var code = "ul#nav.menu > li > a /about About Us";
        var lexer = new Lexer(code);
        var parser = new Parser(lexer.tokenize());
        var compiler = new HtmlCompiler();
        var html = compiler.compile(parser.parse());

        Assert.equals('<ul id="nav" class="menu"><li><a href="/about">About Us</a></li></ul>', html);
    }

    function testVoidTagRendering():Void {
        var code = 'img (src="/logo.png" alt="Logo")';
        var lexer = new Lexer(code);
        var parser = new Parser(lexer.tokenize());
        var compiler = new HtmlCompiler();
        var html = compiler.compile(parser.parse());

        Assert.equals('<img src="/logo.png" alt="Logo" />', html);
    }

    function testContextInterpolation():Void {
        var code = 'p Hello {user}!';
        var lexer = new Lexer(code);
        var parser = new Parser(lexer.tokenize());
        var ctx = ["user" => "Alice"];
        var compiler = new HtmlCompiler(ctx);
        var html = compiler.compile(parser.parse());

        Assert.equals('<p>Hello Alice!</p>', html);
    }

    function testViewComposition():Void {
        var code = "@view user-card name\n  div.card\n    p {name}\n\n@user-card Alice";
        var lexer = new Lexer(code);
        var parser = new Parser(lexer.tokenize());
        var compiler = new HtmlCompiler();
        var html = compiler.compile(parser.parse());

        Assert.equals('<div class="card"><p>Alice</p></div>', html);
    }
}
