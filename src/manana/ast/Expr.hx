package manana.ast;

enum TextSegment {
    TLiteral(value:String);
    TInterpolation(path:Array<String>);
}

typedef Metadata = {
    var name:String;
    var value:Null<String>;
    var pos:Position;
}

enum ExprDef {
    EView(name:String, args:Array<String>, meta:Array<Metadata>, children:Array<Expr>);
    EElement(tag:String, id:Null<String>, classes:Array<String>, attrs:Map<String, String>, children:Array<Expr>);
    EText(segments:Array<TextSegment>);
    ECodeBlock(rawCode:String, indentLevel:Int);
    EViewCall(targetView:String, flags:Array<String>);
}

class Expr {
    public final def:ExprDef;
    public final pos:Position;

    public function new(def:ExprDef, pos:Position) {
        this.def = def;
        this.pos = pos;
    }
}
