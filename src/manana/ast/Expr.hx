package manana.ast;

enum SExprDef {
    SAtom(value:String);
    SCall(name:String, args:Array<SExpr>);
}

class SExpr {
    public var def:SExprDef;
    public var pos:Position;

    public function new(def:SExprDef, pos:Position) {
        this.def = def;
        this.pos = pos;
    }
}

enum ExprDef {
    EElement(tag:String, id:Null<String>, classes:Array<String>, attrs:Map<String, String>, children:Array<Expr>);
    EText(text:String);
    ECodeBlock(code:String, indent:Int);
    EView(name:String, args:Array<String>, meta:Array<Metadata>, children:Array<Expr>);
    ECall(sexpr:SExpr, children:Array<Expr>);
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
