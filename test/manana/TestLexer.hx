package manana;

import manana.lexer.Lexer;
import manana.lexer.Token;

class TestLexer {
    public function new() {}

    public function runAll():Void {
        Sys.println("Running TestLexer...");
        testIndentationTokens();
        testTagAndSelectorLexing();
        testSlashPathShorthand();
        testAttributeMapLexing();
        testDirectivesAndMetadata();
        testInterpolationLexing();
        testCodeBlockLexing();
        testTripleQuoteCommentSkipping();
    }

    function testIndentationTokens():Void {
        var code = "div\n  p\n    a";
        var lexer = new Lexer(code);
        var tokens = lexer.tokenize();

        Assert.equals(8, tokens.length);
        Assert.isTrue(matchToken(tokens[0], TIdentifier("div")));
        Assert.isTrue(matchToken(tokens[1], TIndent(2)));
        Assert.isTrue(matchToken(tokens[2], TIdentifier("p")));
        Assert.isTrue(matchToken(tokens[3], TIndent(4)));
        Assert.isTrue(matchToken(tokens[4], TIdentifier("a")));
        Assert.isTrue(matchToken(tokens[5], TDedent(2)));
        Assert.isTrue(matchToken(tokens[6], TDedent(0)));
        Assert.isTrue(matchToken(tokens[7], TEof));
    }

    function testTagAndSelectorLexing():Void {
        var code = "div#page.container.width-full";
        var lexer = new Lexer(code);
        var tokens = lexer.tokenize();

        Assert.isTrue(matchToken(tokens[0], TIdentifier("div")));
        Assert.isTrue(matchToken(tokens[1], TId("page")));
        Assert.isTrue(matchToken(tokens[2], TClass("container")));
        Assert.isTrue(matchToken(tokens[3], TClass("width-full")));
    }

    function testSlashPathShorthand():Void {
        var code = "a /about About Us";
        var lexer = new Lexer(code);
        var tokens = lexer.tokenize();

        Assert.isTrue(matchToken(tokens[0], TIdentifier("a")));
        Assert.isTrue(matchToken(tokens[1], TSlashPath("/about")));
        Assert.isTrue(matchToken(tokens[2], TText("About Us")));
    }

    function testAttributeMapLexing():Void {
        var code = "a (href=\"/syntax\" id=my-id)";
        var lexer = new Lexer(code);
        var tokens = lexer.tokenize();

        Assert.isTrue(matchToken(tokens[0], TIdentifier("a")));
        Assert.isTrue(matchToken(tokens[1], TAttrOpen));
        Assert.isTrue(matchToken(tokens[2], TIdentifier("href")));
        Assert.isTrue(matchToken(tokens[3], TEquals));
        Assert.isTrue(matchToken(tokens[4], TString("/syntax")));
        Assert.isTrue(matchToken(tokens[5], TIdentifier("id")));
        Assert.isTrue(matchToken(tokens[6], TEquals));
        Assert.isTrue(matchToken(tokens[7], TIdentifier("my-id")));
        Assert.isTrue(matchToken(tokens[8], TAttrClose));
    }

    function testDirectivesAndMetadata():Void {
        var code = "@view left-nav ^:manana/allow-missing";
        var lexer = new Lexer(code);
        var tokens = lexer.tokenize();

        Assert.isTrue(matchToken(tokens[0], TDirective("view")));
        Assert.isTrue(matchToken(tokens[1], TText("left-nav")));
        Assert.isTrue(matchToken(tokens[2], TMetadata("^:manana/allow-missing")));
    }

    function testInterpolationLexing():Void {
        var code = "{$ user.first-name}";
        var lexer = new Lexer(code);
        var tokens = lexer.tokenize();

        Assert.isTrue(matchToken(tokens[0], TLBrace));
        Assert.isTrue(matchToken(tokens[1], TIdentifier("$")));
        Assert.isTrue(matchToken(tokens[2], TIdentifier("user.first-name")));
        Assert.isTrue(matchToken(tokens[3], TRBrace));
    }

    function testCodeBlockLexing():Void {
        var code = "```\nif (x === 1) {\n  return true;\n}\n```";
        var lexer = new Lexer(code);
        var tokens = lexer.tokenize();

        switch (tokens[0].def) {
            case TCodeBlock(rawCode):
                Assert.isTrue(rawCode.indexOf("if (x === 1)") != -1);
            default:
                Assert.isTrue(false);
        }
    }

    function testTripleQuoteCommentSkipping():Void {
        var code = '"""\nThis is a comment\n"""\ndiv';
        var lexer = new Lexer(code);
        var tokens = lexer.tokenize();

        Assert.isTrue(matchToken(tokens[0], TIdentifier("div")));
    }

    function matchToken(tok:Token, expectedDef:TokenDef):Bool {
        return Type.enumEq(tok.def, expectedDef);
    }
}
