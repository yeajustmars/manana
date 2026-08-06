package manana.ast;

enum TextSegment {
    TLiteral(text:String);
    TInterpolation(path:Array<String>, raw:Bool);
}

enum ExprDef {
    EElement(tag:String, id:Null<String>, classes:Array<String>, attrs:Map<String, String>, children:Array<Expr>);
    EText(segments:Array<TextSegment>);
    ECodeBlock(code:String, indent:Int);
    EView(name:String, args:Array<String>, meta:Array<Metadata>, children:Array<Expr>);
    EViewCall(name:String, flags:Array<String>);
}

typedef Metadata = {
    var name:String;
    var value:Null<String>;
    var pos:Position;
}

class Expr {
    public var def:ExprDef;
    public var pos:Position;

    public function new(def:ExprDef, pos:Position) {
        this.def = def;
        this.pos = pos;
    }
}
