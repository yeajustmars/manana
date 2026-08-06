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
            statements.push(parseStatement());
        }
        return statements;
    }

    function parseStatement():Expr {
        var tok = peek();

        return switch (tok.def) {
            case TDirective(name):
                if (name == "view") {
                    parseViewDefinition();
                } else {
                    // General directive or view call shorthand
                    parseViewCallOrDirective();
                }
            case TIdentifier(_), TId(_), TClass(_):
                parseElementOrChain();
            case TCodeBlock(code):
                advance();
                new Expr(ECodeBlock(code, 0), tok.pos);
            case TText(_), TInterpolation(_):
                parseTextStatement();
            case TSlashPath(_):
                // Standalone link sugar fallback starting with implicit a tag
                parseElementOrChain();
            default:
                throw new MananaError('Unexpected token ${tok.def}', tok.pos);
        }
    }

    function parseViewDefinition():Expr {
        var startTok = advance(); // consume @view
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
                case TIdentifier(argName):
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
        var startTok = advance(); // consume @
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
                default:
                    advance();
            }
        }

        var children = parseIndentedBlock();
        // If it has children, treat as inline element; otherwise view call
        return new Expr(EViewCall(name, flags), startTok.pos);
    }

    function parseElementOrChain():Expr {
        var rootElement = parseSingleElement();
        var currentTerminal = rootElement;

        while (checkChain()) {
            advance(); // consume >

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
                case TIdentifier(t): tag = t;
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
            advance(); // consume (
            while (!isAtEnd() && !checkAttrClose()) {
                if (matchIdentifier()) {
                    var k = advance();
                    var keyStr = switch (k.def) { case TIdentifier(s): s; default: ""; };
                    var valStr = "true";

                    if (checkEquals()) {
                        advance(); // consume =
                        var v = advance();
                        valStr = switch (v.def) {
                            case TString(s), TIdentifier(s), TSlashPath(s): s;
                            default: "";
                        };
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

        if (!isAtEnd() && !isLineBreakOrIndent(peek()) && !checkChain()) {
            children.push(parseTextStatement());
        }

        return new Expr(EElement(tag, id, classes, attrs, children), pos);
    }

    function parseTextStatement():Expr {
        var segments:Array<TextSegment> = [];
        var pos = peek().pos;
        var textBuf = new StringBuf();

        while (!isAtEnd() && !isLineBreakOrIndent(peek()) && !checkChain()) {
            var tok = peek();
            switch (tok.def) {
                case TInterpolation(path):
                    if (textBuf.length > 0) {
                        segments.push(TLiteral(textBuf.toString()));
                        textBuf = new StringBuf();
                    }
                    segments.push(TInterpolation(path));
                    advance();
                case TText(val), TIdentifier(val):
                    textBuf.add(val);
                    advance();
                default:
                    var str = tokenToString(tok);
                    if (str != "") {
                        textBuf.add(str);
                    }
                    advance();
            }
        }

        if (textBuf.length > 0) {
            segments.push(TLiteral(textBuf.toString()));
        }

        return new Expr(EText(segments), pos);
    }

    function parseIndentedBlock():Array<Expr> {
        var children:Array<Expr> = [];
        skipNewlines();

        if (checkIndent()) {
            advance(); // consume TIndent
            while (!isAtEnd() && !checkDedent()) {
                skipNewlines();
                if (checkDedent()) break;
                children.push(parseStatement());
            }
            if (checkDedent()) advance(); // consume TDedent
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
            case TIdentifier(_): true;
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

    inline function checkText():Bool {
        if (isAtEnd()) return false;
        return switch (peek().def) {
            case TText(_): true;
            default: false;
        }
    }

    inline function checkInterpolation():Bool {
        if (isAtEnd()) return false;
        return switch (peek().def) {
            case TInterpolation(_): true;
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
            case TText(s), TIdentifier(s), TString(s), TSlashPath(s), TId(s), TClass(s): s;
            default: "";
        }
    }
}
