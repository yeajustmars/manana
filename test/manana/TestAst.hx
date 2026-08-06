package manana;

import manana.ast.Position;
import manana.ast.MananaError;
import manana.ast.Expr;

class TestAst {
    public function new() {}

    public function runAll():Void {
        Sys.println("Running TestAst...");
        testPositionFormatting();
        testErrorFormatting();
        testImplicitTagAstNode();
    }

    function testPositionFormatting():Void {
        var pos = new Position("main.mn", 12, 4);
        Assert.equals("main.mn:12:4", pos.toString());
    }

    function testErrorFormatting():Void {
        var pos = new Position("main.mn", 5, 1);
        var err = new MananaError("Unexpected token", pos);
        Assert.equals("[Manana Syntax Error] Unexpected token at main.mn:5:1", err.toString());
    }

    function testImplicitTagAstNode():Void {
        var pos = new Position("main.mn", 1, 1);
        var elem = new Expr(EElement("div", "page", ["container", "full-width"], new Map(), []), pos);

        switch (elem.def) {
            case EElement(tag, id, classes, attrs, children):
                Assert.equals("div", tag);
                Assert.equals("page", id);
                Assert.equals(2, classes.length);
            default:
                Assert.isTrue(false);
        }
    }
}
