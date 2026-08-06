package manana.codegen;

import manana.ast.Expr;

typedef ViewDef = {
    args:Array<String>,
    children:Array<Expr>
}

class HtmlCompiler {
    static final VOID_TAGS:Map<String, Bool> = [
        "area" => true, "base" => true, "br" => true, "col" => true, "embed" => true,
        "hr" => true, "img" => true, "input" => true, "link" => true, "meta" => true,
        "param" => true, "source" => true, "track" => true, "wbr" => true
    ];

    var scopeStack:Array<Map<String, Dynamic>>;
    var views:Map<String, ViewDef> = new Map();

    public function new(context:Null<Map<String, Dynamic>> = null) {
        this.scopeStack = [context != null ? context : new Map()];
    }

    public function compile(ast:Array<Expr>):String {
        // First pass: Register all view definitions
        for (expr in ast) {
            switch (expr.def) {
                case EView(name, args, _, children):
                    views.set(name, { args: args, children: children });
                default:
            }
        }

        // Second pass: Render output nodes
        var buf = new StringBuf();
        for (expr in ast) {
            buf.add(compileExpr(expr));
        }
        return buf.toString();
    }

    public function compileExpr(expr:Expr):String {
        return switch (expr.def) {
            case EElement(tag, id, classes, attrs, children):
                var buf = new StringBuf();
                buf.add('<$tag');

                if (id != null) {
                    buf.add(' id="$id"');
                }

                if (classes.length > 0) {
                    buf.add(' class="${classes.join(" ")}"');
                }

                for (key in attrs.keys()) {
                    var val = attrs.get(key);
                    if (val == "true") {
                        buf.add(' $key');
                    } else {
                        buf.add(' $key="$val"');
                    }
                }

                if (VOID_TAGS.exists(tag.toLowerCase())) {
                    buf.add(' />');
                } else {
                    buf.add('>');
                    for (child in children) {
                        buf.add(compileExpr(child));
                    }
                    buf.add('</$tag>');
                }
                buf.toString();

            case EText(segments):
                var buf = new StringBuf();
                for (seg in segments) {
                    switch (seg) {
                        case TLiteral(text):
                            buf.add(text);
                        case TInterpolation(path):
                            buf.add(resolveContextPath(path));
                    }
                }
                buf.toString();

            case ECodeBlock(code, _):
                code;

            case EView(name, args, _, children):
                ""; // Declarations produce no direct output

            case EViewCall(name, flags):
                if (!views.exists(name)) return "";
                var viewDef = views.get(name);

                var localScope = new Map<String, Dynamic>();
                for (i in 0...viewDef.args.length) {
                    if (i < flags.length) {
                        localScope.set(viewDef.args[i], flags[i]);
                    }
                }

                scopeStack.push(localScope);
                var buf = new StringBuf();
                for (child in viewDef.children) {
                    buf.add(compileExpr(child));
                }
                scopeStack.pop();
                buf.toString();
        }
    }

    function resolveContextPath(path:Array<String>):String {
        if (path.length == 0) return "";
        var key = path[0];

        var i = scopeStack.length - 1;
        while (i >= 0) {
            var scope = scopeStack[i];
            if (scope.exists(key)) {
                return Std.string(scope.get(key));
            }
            i--;
        }

        return "";
    }
}
