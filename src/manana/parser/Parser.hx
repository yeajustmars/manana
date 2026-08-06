package manana.parser;

import manana.ast.Expr;
import manana.ast.MananaError;
import manana.ast.Position;
import manana.lexer.Token;

class Parser {
    final tokens:Array<Token>;
    var cursor:Int = 0;

    public function new(tokens:Array<Token>) {
        this.tokens = tokens;
    }

    public function parse():Array<Expr> {
        var statements:Array<Expr> = [];
        while (!isAtEnd()) {
            skipNewlines();
            if (isAtEnd()) break;
            parseStatementsOnLine(statements);
        }
        return statements;
    }

    function parseStatementsOnLine(out:Array<Expr>):Void {
        var tok = peek();

        switch (tok.def) {
            case TDirective(name):
                if (name == "view") {
                    out.push(parseViewDefinition());
                } else {
                    out.push(parseViewCallOrDirective());
                }
            case TIdentifier(_), TId(_), TClass(_), TSlashPath(_):
                out.push(parseElementOrChain());
            case TLBrace:
                out.push(parseCallStatement());
            case TCodeBlock(code):
                advance();
                out.push(new Expr(ECodeBlock(code, 0), tok.pos));
            default:
                parseTextLineInto(out);
        }
    }

    function parseCallStatement():Expr {
        var pos = peek().pos;
        var sexpr = parseSExpr();
        var children = parseIndentedBlock();
        return new Expr(ECall(sexpr, children), pos);
    }

    public function parseSExpr():SExpr {
        var pos = peek().pos;
        if (checkLBrace()) {
            advance(); // consume {
            if (checkRBrace()) {
                advance();
                return new SExpr(SCall("", []), pos);
            }

            var fnName = "";
            var args:Array<SExpr> = [];

            if (checkLBrace()) {
                var nested = parseSExpr();
                fnName = formatSExprName(nested);
            } else {
                var fnTok = advance();
                fnName = tokenToSymbolOrName(fnTok);
            }

            while (!isAtEnd() && !checkRBrace()) {
                if (checkLBrace()) {
                    args.push(parseSExpr());
                } else {
                    var argTok = advance();
                    args.push(tokenToSExpr(argTok));
                }
            }

            if (checkRBrace()) advance(); // consume }

            return new SExpr(SCall(fnName, args), pos);
        } else {
            var tok = advance();
            return tokenToSExpr(tok);
        }
    }

    function tokenToSExpr(tok:Token):SExpr {
        return switch (tok.def) {
            case TSymbol(s), TIdentifier(s): new SExpr(SSymbol(s), tok.pos);
            case TKeyword(k): new SExpr(SKeyword(k), tok.pos);
            case TString(s): new SExpr(SString(s), tok.pos);
            case TInt(i): new SExpr(SInt(i), tok.pos);
            case TFloat(f): new SExpr(SFloat(f), tok.pos);
            case TBool(b): new SExpr(SBool(b), tok.pos);
            default: new SExpr(SSymbol(tokenToString(tok)), tok.pos);
        }
    }

    function parseViewDefinition():Expr {
        var startTok = advance();
        var viewName = "";
        var args:Array<String> = [];
        var meta:Array<Metadata> = [];

        while (!isAtEnd() && !isLineBreakOrIndent(peek())) {
            var t = peek();
            switch (t.def) {
                case TMetadata(mName):
                    meta.push({ name: mName, value: null, pos: t.pos });
                    advance();
                case TText(val):
                    advance();
                    var parts = val.split(" ").map(StringTools.trim).filter(function(s) return s.length > 0);
                    if (parts.length > 0 && viewName == "") {
                        viewName = parts[0];
                        for (i in 1...parts.length) args.push(parts[i]);
                    } else {
                        for (p in parts) args.push(p);
                    }
                case TIdentifier(argName), TSymbol(argName):
                    advance();
                    if (viewName == "") viewName = argName;
                    else args.push(argName);
                default:
                    advance();
            }
        }

        var children = parseIndentedBlock();
        return new Expr(EView(viewName, args, meta, children), startTok.pos);
    }

    function parseViewCallOrDirective():Expr {
        var startTok = advance();
        var name = switch (startTok.def) {
            case TDirective(n): n;
            default: "";
        }

        var flags:Array<String> = [];
        while (!isAtEnd() && !isLineBreakOrIndent(peek())) {
            var t = peek();
            switch (t.def) {
                case TMetadata(m):
                    flags.push(m);
                    advance();
                case TText(val):
                    advance();
                    var parts = val.split(" ").map(StringTools.trim).filter(function(s) return s.length > 0);
                    for (p in parts) flags.push(p);
                case TIdentifier(argName), TSymbol(argName), TString(argName), TSlashPath(argName):
                    flags.push(argName);
                    advance();
                default:
                    var str = tokenToString(t);
                    if (str != "") flags.push(str);
                    advance();
            }
        }

        var children = parseIndentedBlock();
        return new Expr(EViewCall(name, flags), startTok.pos);
    }

    function parseElementOrChain():Expr {
        var rootElement = parseSingleElement();
        var currentTerminal = rootElement;

        while (checkChain()) {
            advance();

            switch (currentTerminal.def) {
                case EText(_):
                    throw new MananaError("Cannot chain element onto a text node", currentTerminal.pos);
                default:
            }

            var nextElement = parseSingleElement();

            switch (currentTerminal.def) {
                case EElement(_, _, _, _, children):
                    children.push(nextElement);
                default:
            }

            currentTerminal = nextElement;
        }

        var indentedChildren = parseIndentedBlock();
        if (indentedChildren.length > 0) {
            switch (currentTerminal.def) {
                case EElement(_, _, _, _, children):
                    for (child in indentedChildren) children.push(child);
                case EText(_):
                    throw new MananaError("Cannot attach indented children to a pure text node", currentTerminal.pos);
                default:
            }
        }

        return rootElement;
    }

    function parseSingleElement():Expr {
        var pos = peek().pos;
        var tag = "div";
        var id:Null<String> = null;
        var classes:Array<String> = [];
        var attrs:Map<String, String> = new Map();

        if (matchIdentifier()) {
            var tok = advance();
            switch (tok.def) {
                case TIdentifier(t), TSymbol(t): tag = t;
                default:
            }
        }

        while (!isAtEnd()) {
            var t = peek();
            switch (t.def) {
                case TId(i):
                    id = i;
                    advance();
                case TClass(c):
                    classes.push(c);
                    advance();
                default:
                    break;
            }
        }

        if (checkAttrOpen()) {
            advance();
            while (!isAtEnd() && !checkAttrClose()) {
                if (matchIdentifier()) {
                    var k = advance();
                    var keyStr = tokenToString(k);
                    var valStr = "true";

                    if (checkEquals()) {
                        advance();
                        var v = advance();
                        valStr = tokenToString(v);
                    }
                    attrs.set(keyStr, valStr);
                } else {
                    advance();
                }
            }
            if (checkAttrClose()) advance();
        }

        if (checkSlashPath()) {
            var tok = advance();
            switch (tok.def) {
                case TSlashPath(p): attrs.set("href", p);
                default:
            }
        }

        var children:Array<Expr> = [];

        while (!isAtEnd() && !isLineBreakOrIndent(peek()) && !checkChain()) {
            if (checkLBrace()) {
                var callPos = peek().pos;
                var sexpr = parseSExpr();
                children.push(new Expr(ECall(sexpr, []), callPos));
            } else {
                var txtTok = advance();
                var txt = tokenToString(txtTok);
                if (txt != "") children.push(new Expr(EText(txt), txtTok.pos));
            }
        }

        return new Expr(EElement(tag, id, classes, attrs, children), pos);
    }

    function parseTextLineInto(out:Array<Expr>):Void {
        while (!isAtEnd() && !isLineBreakOrIndent(peek())) {
            if (checkLBrace()) {
                var callPos = peek().pos;
                var sexpr = parseSExpr();
                out.push(new Expr(ECall(sexpr, []), callPos));
            } else {
                var tok = advance();
                var txt = tokenToString(tok);
                if (txt != "") out.push(new Expr(EText(txt), tok.pos));
            }
        }
    }

    function parseIndentedBlock():Array<Expr> {
        var children:Array<Expr> = [];
        skipNewlines();

        if (checkIndent()) {
            advance();
            while (!isAtEnd() && !checkDedent()) {
                skipNewlines();
                if (checkDedent()) break;
                parseStatementsOnLine(children);
            }
            if (checkDedent()) advance();
        }

        return children;
    }

    inline function isAtEnd():Bool return cursor >= tokens.length || checkEof();
    inline function peek():Token return tokens[cursor];
    inline function advance():Token return tokens[cursor++];

    inline function checkEof():Bool {
        if (cursor >= tokens.length) return true;
        return switch (peek().def) {
            case TEof: true;
            default: false;
        }
    }

    inline function checkChain():Bool {
        if (isAtEnd()) return false;
        return switch (peek().def) {
            case TChain: true;
            default: false;
        }
    }

    inline function checkLBrace():Bool {
        if (isAtEnd()) return false;
        return switch (peek().def) {
            case TLBrace: true;
            default: false;
        }
    }

    inline function checkRBrace():Bool {
        if (isAtEnd()) return false;
        return switch (peek().def) {
            case TRBrace: true;
            default: false;
        }
    }

    inline function checkAttrOpen():Bool {
        if (isAtEnd()) return false;
        return switch (peek().def) {
            case TAttrOpen: true;
            default: false;
        }
    }

    inline function checkAttrClose():Bool {
        if (isAtEnd()) return false;
        return switch (peek().def) {
            case TAttrClose: true;
            default: false;
        }
    }

    inline function checkEquals():Bool {
        if (isAtEnd()) return false;
        return switch (peek().def) {
            case TEquals: true;
            default: false;
        }
    }

    inline function checkIndent():Bool {
        if (isAtEnd()) return false;
        return switch (peek().def) {
            case TIndent(_): true;
            default: false;
        }
    }

    inline function checkDedent():Bool {
        if (isAtEnd()) return false;
        return switch (peek().def) {
            case TDedent(_): true;
            default: false;
        }
    }

    inline function matchIdentifier():Bool {
        if (isAtEnd()) return false;
        return switch (peek().def) {
            case TIdentifier(_), TSymbol(_): true;
            default: false;
        }
    }

    inline function checkSlashPath():Bool {
        if (isAtEnd()) return false;
        return switch (peek().def) {
            case TSlashPath(_): true;
            default: false;
        }
    }

    inline function isLineBreakOrIndent(t:Token):Bool {
        return switch (t.def) {
            case TNewline, TEof: true;
            case TIndent(_), TDedent(_): true;
            default: false;
        }
    }

    function skipNewlines():Void {
        while (!isAtEnd()) {
            switch (peek().def) {
                case TNewline: advance();
                default: break;
            }
        }
    }

    function tokenToString(tok:Token):String {
        return switch (tok.def) {
            case TText(s), TIdentifier(s), TSymbol(s), TKeyword(s), TString(s), TSlashPath(s), TId(s), TClass(s): s;
            case TInt(i): Std.string(i);
            case TFloat(f): Std.string(f);
            case TBool(b): Std.string(b);
            default: "";
        }
    }

    function tokenToSymbolOrName(tok:Token):String {
        return switch (tok.def) {
            case TSymbol(s), TIdentifier(s): s;
            default: tokenToString(tok);
        }
    }

    function formatSExprName(sexpr:SExpr):String {
        return switch (sexpr.def) {
            case SSymbol(s): s;
            case SCall(n, _): n;
            default: "";
        }
    }
}
