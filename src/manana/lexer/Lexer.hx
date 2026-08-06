package manana.lexer;

import manana.ast.Position;
import manana.ast.MananaError;
import manana.lexer.Token;

class Lexer {
    static final HTML_TAGS:Map<String, Bool> = [
        "a" => true, "abbr" => true, "address" => true, "area" => true, "article" => true,
        "aside" => true, "audio" => true, "b" => true, "base" => true, "bdi" => true,
        "bdo" => true, "blockquote" => true, "body" => true, "br" => true, "button" => true,
        "canvas" => true, "caption" => true, "cite" => true, "code" => true, "col" => true,
        "colgroup" => true, "data" => true, "datalist" => true, "dd" => true, "del" => true,
        "details" => true, "dfn" => true, "dialog" => true, "div" => true, "dl" => true,
        "dt" => true, "em" => true, "embed" => true, "fieldset" => true, "figcaption" => true,
        "figure" => true, "footer" => true, "form" => true, "h1" => true, "h2" => true,
        "h3" => true, "h4" => true, "h5" => true, "h6" => true, "head" => true,
        "header" => true, "hr" => true, "html" => true, "i" => true, "iframe" => true,
        "img" => true, "input" => true, "ins" => true, "kbd" => true, "label" => true,
        "legend" => true, "li" => true, "link" => true, "main" => true, "map" => true,
        "mark" => true, "meta" => true, "meter" => true, "nav" => true, "noscript" => true,
        "object" => true, "ol" => true, "optgroup" => true, "option" => true, "output" => true,
        "p" => true, "param" => true, "picture" => true, "pre" => true, "progress" => true,
        "q" => true, "rp" => true, "rt" => true, "ruby" => true, "s" => true,
        "samp" => true, "script" => true, "section" => true, "select" => true, "small" => true,
        "source" => true, "span" => true, "strong" => true, "style" => true, "sub" => true,
        "summary" => true, "sup" => true, "svg" => true, "table" => true, "tbody" => true,
        "td" => true, "template" => true, "textarea" => true, "tfoot" => true, "th" => true,
        "thead" => true, "time" => true, "title" => true, "tr" => true, "track" => true,
        "u" => true, "ul" => true, "var" => true, "video" => true, "wbr" => true
    ];

    final source:String;
    final fileName:String;
    var cursor:Int = 0;
    var line:Int = 1;
    var col:Int = 1;
    var indentStack:Array<Int> = [0];
    var atLineStart:Bool = true;
    var inAttrMode:Bool = false;

    public function new(source:String, fileName:String = "main.mn") {
        this.source = source;
        this.fileName = fileName;
    }

    public function tokenize():Array<Token> {
        var tokens:Array<Token> = [];

        while (!isEof()) {
            if (atLineStart) {
                var indentChars = consumeIndentation();

                if (peekChar() == "\n" || peekChar() == "\r" || startsWith('"""')) {
                    if (peekChar() == "\r") advance();
                    if (peekChar() == "\n") { advance(); line++; col = 1; }
                    else if (startsWith('"""')) skipBlockComment();
                    continue;
                }

                if (isEof()) break;

                var prevIndent = indentStack[indentStack.length - 1];
                if (indentChars > prevIndent) {
                    indentStack.push(indentChars);
                    tokens.push(makeToken(TIndent(indentChars)));
                } else if (indentChars < prevIndent) {
                    while (indentStack.length > 1 && indentStack[indentStack.length - 1] > indentChars) {
                        indentStack.pop();
                        tokens.push(makeToken(TDedent(indentStack[indentStack.length - 1])));
                    }
                    if (indentStack[indentStack.length - 1] != indentChars) {
                        throw new MananaError('Inconsistent indentation level ($indentChars spaces)', currentPos());
                    }
                } else if (tokens.length > 0 && !isIndentDedent(tokens[tokens.length - 1])) {
                    tokens.push(makeToken(TNewline));
                }
                atLineStart = false;
            }

            skipInlineWhitespace();
            if (isEof()) break;

            var ch = peekChar();

            if (startsWith('"""')) {
                skipBlockComment();
                continue;
            }

            if (startsWith("```")) {
                tokens.push(lexCodeBlock());
                continue;
            }

            if (ch == "\n" || ch == "\r") {
                if (ch == "\r") advance();
                advance();
                line++;
                col = 1;
                atLineStart = true;
                inAttrMode = false;
                continue;
            }

            if (ch == "\\") {
                advance();
                tokens.push(lexRestOfLineAsText());
                continue;
            }

            if (inAttrMode) {
                if (ch == ")") {
                    inAttrMode = false;
                    tokens.push(makeTokenAndAdvance(TAttrClose));
                    continue;
                }
                if (ch == "=") {
                    tokens.push(makeTokenAndAdvance(TEquals));
                    continue;
                }
                if (ch == '"' || ch == "'") {
                    tokens.push(lexString(ch));
                    continue;
                }
                tokens.push(lexIdentifierOrValue());
                continue;
            }

            if (ch == "(") {
                inAttrMode = true;
                tokens.push(makeTokenAndAdvance(TAttrOpen));
                continue;
            }
            if (ch == ">") {
                tokens.push(makeTokenAndAdvance(TChain));
                continue;
            }
            if (ch == "@") {
                tokens.push(lexDirective());
                continue;
            }
            if (ch == "^") {
                tokens.push(lexMetadata());
                continue;
            }
            if (ch == "#") {
                tokens.push(lexId());
                continue;
            }
            if (ch == ".") {
                tokens.push(lexClass());
                continue;
            }
            if (ch == "/") {
                tokens.push(lexSlashPath());
                continue;
            }
            if (ch == "{") {
                tokens.push(lexInterpolation());
                continue;
            }

            if (isAlpha(ch)) {
                var word = peekWord();
                if (HTML_TAGS.exists(word.toLowerCase())) {
                    var pos = currentPos();
                    advanceBy(word.length);
                    tokens.push(new Token(TIdentifier(word), pos));
                    continue;
                }
            }

            tokens.push(lexTextUntilSpecial());
        }

        while (indentStack.length > 1) {
            indentStack.pop();
            tokens.push(makeToken(TDedent(indentStack[indentStack.length - 1])));
        }

        tokens.push(makeToken(TEof));
        return tokens;
    }

    function consumeIndentation():Int {
        var count = 0;
        while (!isEof()) {
            var c = peekChar();
            if (c == " ") count++;
            else if (c == "\t") count += 4;
            else break;
            advance();
        }
        return count;
    }

    function skipInlineWhitespace():Void {
        while (!isEof()) {
            var c = peekChar();
            if (c == " " || c == "\t") advance();
            else break;
        }
    }

    function skipBlockComment():Void {
        advanceBy(3);
        while (!isEof() && !startsWith('"""')) {
            if (peekChar() == "\n") { line++; col = 1; }
            advance();
        }
        if (startsWith('"""')) advanceBy(3);
    }

    function lexCodeBlock():Token {
        var pos = currentPos();
        advanceBy(3);

        while (!isEof() && peekChar() != "\n") advance();
        if (peekChar() == "\n") { advance(); line++; col = 1; }

        var rawBuffer = new StringBuf();
        var baseIndent = -1;

        while (!isEof() && !startsWith("```")) {
            var currentLineIndent = 0;

            while (!isEof() && (peekChar() == " " || peekChar() == "\t")) {
                currentLineIndent += (peekChar() == "\t") ? 4 : 1;
                advance();
            }

            if (peekChar() == "\n" || peekChar() == "\r") {
                rawBuffer.add("\n");
                if (peekChar() == "\r") advance();
                advance(); line++; col = 1;
                continue;
            }

            if (startsWith("```")) break;

            if (baseIndent == -1) baseIndent = currentLineIndent;

            while (!isEof() && peekChar() != "\n" && peekChar() != "\r") {
                rawBuffer.add(peekChar());
                advance();
            }
            rawBuffer.add("\n");

            if (peekChar() == "\r") advance();
            if (peekChar() == "\n") { advance(); line++; col = 1; }
        }

        if (startsWith("```")) advanceBy(3);

        return new Token(TCodeBlock(StringTools.trim(rawBuffer.toString())), pos);
    }

    function lexDirective():Token {
        var pos = currentPos();
        advance();
        var name = readIdentifierName();
        return new Token(TDirective(name), pos);
    }

    function lexMetadata():Token {
        var pos = currentPos();
        var buf = new StringBuf();
        while (!isEof() && !isWhitespace(peekChar()) && peekChar() != "\n") {
            buf.add(peekChar());
            advance();
        }
        return new Token(TMetadata(buf.toString()), pos);
    }

    function lexId():Token {
        var pos = currentPos();
        advance();
        return new Token(TId(readIdentifierName()), pos);
    }

    function lexClass():Token {
        var pos = currentPos();
        advance();
        return new Token(TClass(readIdentifierName()), pos);
    }

    function lexSlashPath():Token {
        var pos = currentPos();
        advance();
        var buf = new StringBuf();
        buf.add("/");
        while (!isEof() && !isWhitespace(peekChar()) && peekChar() != "\n") {
            buf.add(peekChar());
            advance();
        }
        return new Token(TSlashPath(buf.toString()), pos);
    }

    function lexInterpolation():Token {
        var pos = currentPos();
        advance(); // skip {
        var raw = false;
        if (peekChar() == "!") {
            raw = true;
            advance(); // skip !
        }
        var buf = new StringBuf();
        while (!isEof() && peekChar() != "}") {
            buf.add(peekChar());
            advance();
        }
        if (peekChar() == "}") advance();
        var path = buf.toString().split(".").map(StringTools.trim);
        return new Token(TInterpolation(path, raw), pos);
    }

    function lexString(quote:String):Token {
        var pos = currentPos();
        advance();
        var buf = new StringBuf();
        while (!isEof() && peekChar() != quote) {
            if (peekChar() == "\\") advance();
            buf.add(peekChar());
            advance();
        }
        if (peekChar() == quote) advance();
        return new Token(TString(buf.toString()), pos);
    }

    function lexIdentifierOrValue():Token {
        var pos = currentPos();
        var buf = new StringBuf();
        while (!isEof() && !isWhitespace(peekChar()) && peekChar() != "=" && peekChar() != ")" && peekChar() != "\n") {
            buf.add(peekChar());
            advance();
        }
        return new Token(TIdentifier(buf.toString()), pos);
    }

    function lexRestOfLineAsText():Token {
        var pos = currentPos();
        var buf = new StringBuf();
        while (!isEof() && peekChar() != "\n" && peekChar() != "\r") {
            buf.add(peekChar());
            advance();
        }
        return new Token(TText(StringTools.trim(buf.toString())), pos);
    }

    function lexTextUntilSpecial():Token {
        var pos = currentPos();
        var buf = new StringBuf();
        while (!isEof()) {
            var c = peekChar();
            if (c == "\n" || c == "\r" || c == "{" || c == "^" || c == "@") break;
            buf.add(c);
            advance();
        }
        var str = buf.toString();
        if (!isEof() && (peekChar() == "^" || peekChar() == "@")) {
            str = rtrim(str);
        }
        return new Token(TText(str), pos);
    }

    function rtrim(s:String):String {
        var len = s.length;
        while (len > 0) {
            var c = s.charAt(len - 1);
            if (c == " " || c == "\t" || c == "\r" || c == "\n") len--;
            else break;
        }
        return s.substr(0, len);
    }

    function readIdentifierName():String {
        var buf = new StringBuf();
        while (!isEof() && (isAlphaNum(peekChar()) || peekChar() == "-" || peekChar() == "_")) {
            buf.add(peekChar());
            advance();
        }
        return buf.toString();
    }

    function peekWord():String {
        var i = cursor;
        var buf = new StringBuf();
        while (i < source.length) {
            var c = source.charAt(i);
            if (isAlphaNum(c) || c == "-" || c == "_") {
                buf.add(c);
                i++;
            } else break;
        }
        return buf.toString();
    }

    inline function isIndentDedent(t:Token):Bool {
        return switch (t.def) {
            case TIndent(_), TDedent(_): true;
            default: false;
        }
    }

    inline function peekChar():String return cursor < source.length ? source.charAt(cursor) : "";
    inline function advance():Void { cursor++; col++; }
    inline function advanceBy(n:Int):Void { cursor += n; col += n; }
    inline function isEof():Bool return cursor >= source.length;
    inline function startsWith(sub:String):Bool return source.substr(cursor, sub.length) == sub;
    inline function currentPos():Position return new Position(fileName, line, col);
    inline function isWhitespace(c:String):Bool return c == " " || c == "\t" || c == "\n" || c == "\r";
    inline function isAlpha(c:String):Bool return (c >= "a" && c <= "z") || (c >= "A" && c <= "Z");
    inline function isAlphaNum(c:String):Bool return isAlpha(c) || (c >= "0" && c <= "9");

    inline function makeToken(def:TokenDef):Token {
        return new Token(def, currentPos());
    }

    inline function makeTokenAndAdvance(def:TokenDef):Token {
        var tok = makeToken(def);
        advance();
        return tok;
    }
}
