package manana;

import manana.lexer.Lexer;
import manana.parser.Parser;
import manana.ast.Expr;

class TestParser {
    public function new() {}

    public function runAll():Void {
        Sys.println("Running TestParser...");
        testViewDefinitionParsing();
        testImplicitTagAndSelectors();
        testInlineChaining();
        testAttributeMapAndSlashPath();
    }

    function testViewDefinitionParsing():Void {
        var code = "@view user-card user role\n  div.card\n    p User Card";
        var lexer = new Lexer(code);
        var parser = new Parser(lexer.tokenize());
        var ast = parser.parse();

        Assert.equals(1, ast.length);
        switch (ast[0].def) {
            case EView(name, args, meta, children):
                Assert.equals("user-card", name);
                Assert.equals(2, args.length);
                Assert.equals("user", args[0]);
                Assert.equals("role", args[1]);
                Assert.equals(1, children.length);
            default:
                Assert.isTrue(false);
        }
    }

    function testImplicitTagAndSelectors():Void {
        var code = "#page.container.width-full";
        var lexer = new Lexer(code);
        var parser = new Parser(lexer.tokenize());
        var ast = parser.parse();

        Assert.equals(1, ast.length);
        switch (ast[0].def) {
            case EElement(tag, id, classes, attrs, children):
                Assert.equals("div", tag);
                Assert.equals("page", id);
                Assert.equals(2, classes.length);
                Assert.equals("container", classes[0]);
                Assert.equals("width-full", classes[1]);
            default:
                Assert.isTrue(false);
        }
    }

    function testInlineChaining():Void {
        var code = "ul#nav > li > a /about About Us";
        var lexer = new Lexer(code);
        var parser = new Parser(lexer.tokenize());
        var ast = parser.parse();

        Assert.equals(1, ast.length);
        switch (ast[0].def) {
            case EElement(ulTag, ulId, _, _, ulChildren):
                Assert.equals("ul", ulTag);
                Assert.equals("nav", ulId);
                Assert.equals(1, ulChildren.length);

                switch (ulChildren[0].def) {
                    case EElement(liTag, _, _, _, liChildren):
                        Assert.equals("li", liTag);
                        Assert.equals(1, liChildren.length);

                        switch (liChildren[0].def) {
                            case EElement(aTag, _, _, aAttrs, aChildren):
                                Assert.equals("a", aTag);
                                Assert.equals("/about", aAttrs.get("href"));
                                Assert.equals(1, aChildren.length);
                            default:
                                Assert.isTrue(false);
                        }
                    default:
                        Assert.isTrue(false);
                }
            default:
                Assert.isTrue(false);
        }
    }

    function testAttributeMapAndSlashPath():Void {
        var code = "a (href=\"/syntax\" target=blank) Link";
        var lexer = new Lexer(code);
        var parser = new Parser(lexer.tokenize());
        var ast = parser.parse();

        Assert.equals(1, ast.length);
        switch (ast[0].def) {
            case EElement(tag, _, _, attrs, children):
                Assert.equals("a", tag);
                Assert.equals("/syntax", attrs.get("href"));
                Assert.equals("blank", attrs.get("target"));
                Assert.equals(1, children.length);
            default:
                Assert.isTrue(false);
        }
    }
}
