package manana.lexer;

import manana.ast.Position;

enum TokenDef {
    TDirective(name:String);          // @view, @manana
    TKeyword(name:String);           // view name or sub-keyword
    TIdentifier(name:String);        // tag names, attribute keys
    TClass(name:String);             // .container
    TId(name:String);                // #page
    TSlashPath(path:String);         // /about shorthand
    TString(value:String);           // "literal string"
    TText(value:String);             // raw text content
    TInterpolation(path:Array<String>); // {user.first-name}
    TAttrOpen;                        // (
    TAttrClose;                       // )
    TEquals;                          // =
    TChain;                           // >
    TMetadata(name:String);          // ^:manana/allow-missing
    TCodeBlock(rawCode:String);      // ```...```
    TIndent(depth:Int);              // Generated on line start indent increase
    TDedent(depth:Int);              // Generated on line start indent decrease
    TNewline;                        // Explicit line break
    TEof;
}

class Token {
    public final def:TokenDef;
    public final pos:Position;

    public function new(def:TokenDef, pos:Position) {
        this.def = def;
        this.pos = pos;
    }
}
