package manana.lexer;

import manana.ast.Position;

enum TokenDef {
    TIdentifier(name:String);
    TSymbol(name:String);
    TKeyword(name:String);
    TInt(value:Int);
    TFloat(value:Float);
    TBool(value:Bool);
    TId(id:String);
    TClass(name:String);
    TText(text:String);
    TSlashPath(path:String);
    TAttrOpen;
    TAttrClose;
    TEquals;
    TString(value:String);
    TChain;
    TDirective(name:String);
    TMetadata(name:String);
    TLBrace;
    TRBrace;
    TCodeBlock(code:String);
    TIndent(spaces:Int);
    TDedent(spaces:Int);
    TNewline;
    TEof;
}

class Token {
    public var def:TokenDef;
    public var pos:Position;

    public function new(def:TokenDef, pos:Position) {
        this.def = def;
        this.pos = pos;
    }
}
