package manana.codegen;

import manana.ast.Expr;

typedef MananaFn = (args:Array<SExpr>, children:Array<Expr>, compiler:HtmlCompiler) -> String;

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

    public var scopeStack:Array<Map<String, Dynamic>>;
    var views:Map<String, ViewDef> = new Map();
    var functions:Map<String, MananaFn> = new Map();

    public function new(context:Null<Map<String, Dynamic>> = null) {
        this.scopeStack = [context != null ? context : new Map()];
        registerBuiltinFunctions();
    }

    public function registerFunction(name:String, fn:MananaFn):Void {
        functions.set(name, fn);
    }

    function registerBuiltinFunctions():Void {
        // Escaped interpolation: {$ path}
        registerFunction("$", function(args, children, compiler) {
            if (args.length == 0) return "";
            var val = compiler.evalSExpr(args[0]);
            var str = val != null ? Std.string(val) : "";
            return StringTools.htmlEscape(str, true);
        });

        // Raw unescaped interpolation: {$! path}
        registerFunction("$!", function(args, children, compiler) {
            if (args.length == 0) return "";
            var val = compiler.evalSExpr(args[0]);
            return val != null ? Std.string(val) : "";
        });

        // Conditional execution: {when-exists? val} or {if cond}
        var handleIf = function(args:Array<SExpr>, children:Array<Expr>, compiler:HtmlCompiler) {
            if (args.length == 0) return "";
            var cond = compiler.evalSExpr(args[0]);
            if (compiler.isTruthy(cond)) {
                var buf = new StringBuf();
                for (child in children) buf.add(compiler.compileExpr(child));
                return buf.toString();
            }
            return "";
        };
        registerFunction("when-exists?", handleIf);
        registerFunction("if", handleIf);

        // Scope binding: {with val :as varName} or {with val varName}
        registerFunction("with", function(args, children, compiler) {
            if (args.length < 2) return "";
            var val = compiler.evalSExpr(args[0]);
            var varName = "";

            if (args.length >= 3) {
                switch (args[1].def) {
                    case SKeyword(k) if (k == "as"):
                        varName = compiler.extractSymbolName(args[2]);
                    case SSymbol(a) if (a == "as"):
                        varName = compiler.extractSymbolName(args[2]);
                    default:
                        varName = compiler.extractSymbolName(args[1]);
                }
            } else {
                varName = compiler.extractSymbolName(args[1]);
            }

            var localScope = new Map<String, Dynamic>();
            localScope.set(varName, val);
            compiler.scopeStack.push(localScope);

            var buf = new StringBuf();
            for (child in children) buf.add(compiler.compileExpr(child));

            compiler.scopeStack.pop();
            return buf.toString();
        });

        // Indexed Map / Loop: {map-indexed idxVar itemVar listPath}
        registerFunction("map-indexed", function(args, children, compiler) {
            if (args.length < 3) return "";
            var idxName = compiler.extractSymbolName(args[0]);
            var itemName = compiler.extractSymbolName(args[1]);
            var listVal = compiler.evalSExpr(args[2]);

            var items:Array<Dynamic> = compiler.toArray(listVal);
            var buf = new StringBuf();

            for (i in 0...items.length) {
                var localScope = new Map<String, Dynamic>();
                localScope.set(idxName, i);
                localScope.set(itemName, items[i]);
                compiler.scopeStack.push(localScope);

                for (child in children) {
                    buf.add(compiler.compileExpr(child));
                }

                compiler.scopeStack.pop();
            }

            return buf.toString();
        });

        // Standard Loop: {map itemVar listPath} or {for itemVar listPath}
        var handleMap = function(args:Array<SExpr>, children:Array<Expr>, compiler:HtmlCompiler) {
            if (args.length < 2) return "";
            var itemName = compiler.extractSymbolName(args[0]);
            var listVal = compiler.evalSExpr(args[1]);

            var items:Array<Dynamic> = compiler.toArray(listVal);
            var buf = new StringBuf();

            for (i in 0...items.length) {
                var localScope = new Map<String, Dynamic>();
                localScope.set(itemName, items[i]);
                compiler.scopeStack.push(localScope);

                for (child in children) {
                    buf.add(compiler.compileExpr(child));
                }

                compiler.scopeStack.pop();
            }

            return buf.toString();
        };
        registerFunction("map", handleMap);
        registerFunction("for", handleMap);
        registerFunction("each", handleMap);

        // Item retrieval: {get object indexOrKey}
        registerFunction("get", function(args, children, compiler) {
            if (args.length < 2) return null;
            var target = compiler.evalSExpr(args[0]);
            var keyOrIdx = compiler.evalSExpr(args[1]);
            return compiler.getProperty(target, keyOrIdx);
        });
    }

    public function compile(ast:Array<Expr>):String {
        for (expr in ast) {
            switch (expr.def) {
                case EView(name, args, _, children):
                    views.set(name, { args: args, children: children });
                default:
            }
        }

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

                if (id != null) buf.add(' id="$id"');
                if (classes.length > 0) buf.add(' class="${classes.join(" ")}"');

                for (key in attrs.keys()) {
                    var val = attrs.get(key);
                    if (val == "true") buf.add(' $key');
                    else buf.add(' $key="$val"');
                }

                if (VOID_TAGS.exists(tag.toLowerCase())) {
                    buf.add(' />');
                } else {
                    buf.add('>');
                    for (child in children) buf.add(compileExpr(child));
                    buf.add('</$tag>');
                }
                buf.toString();

            case EText(text):
                text;

            case ECodeBlock(code, _):
                code;

            case EView(_, _, _, _):
                "";

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

            case ECall(sexpr, children):
                execCall(sexpr, children);
        }
    }

    function execCall(sexpr:SExpr, children:Array<Expr>):String {
        return switch (sexpr.def) {
            case SCall(fnName, args):
                if (functions.exists(fnName)) {
                    functions.get(fnName)(args, children, this);
                } else {
                    var val = evalSExpr(sexpr);
                    val != null ? StringTools.htmlEscape(Std.string(val), true) : "";
                }
            case SSymbol(path):
                var val = resolvePath(path);
                val != null ? StringTools.htmlEscape(Std.string(val), true) : "";
            case SInt(_), SFloat(_), SBool(_), SString(_):
                StringTools.htmlEscape(Std.string(evalSExpr(sexpr)), true);
            case SKeyword(k):
                ':$k';
        }
    }

    public function evalSExpr(sexpr:SExpr):Dynamic {
        return switch (sexpr.def) {
            case SSymbol(val): resolvePath(val);
            case SKeyword(val): ':$val';
            case SString(val): val;
            case SInt(val): val;
            case SFloat(val): val;
            case SBool(val): val;
            case SCall(fnName, args):
                if (functions.exists(fnName)) {
                    functions.get(fnName)(args, [], this);
                } else {
                    resolvePath(fnName);
                }
        }
    }

    public function extractSymbolName(sexpr:SExpr):String {
        return switch (sexpr.def) {
            case SSymbol(s): s;
            case SKeyword(k): k;
            case SString(s): s;
            default: "";
        }
    }

    public function resolvePath(pathStr:String):Dynamic {
        if (pathStr == "" || pathStr == null) return null;
        var parts = pathStr.split(".").map(StringTools.trim);
        var rootKey = parts[0];

        var rootVal:Dynamic = null;
        var found = false;

        var i = scopeStack.length - 1;
        while (i >= 0) {
            var scope = scopeStack[i];
            if (scope.exists(rootKey)) {
                rootVal = scope.get(rootKey);
                found = true;
                break;
            }
            i--;
        }

        if (!found || rootVal == null) return null;

        var current:Dynamic = rootVal;
        for (p in 1...parts.length) {
            if (current == null) return null;
            current = getProperty(current, parts[p]);
        }

        return current;
    }

    public function getProperty(target:Dynamic, propOrIdx:Dynamic):Dynamic {
        if (target == null) return null;

        if (Std.isOfType(propOrIdx, Int) && (Std.isOfType(target, Array) || Std.isOfType(target, List))) {
            var idx:Int = cast propOrIdx;
            var arr:Array<Dynamic> = toArray(target);
            if (idx >= 0 && idx < arr.length) return arr[idx];
            return null;
        }

        var prop = Std.string(propOrIdx);
        if (Std.isOfType(target, haxe.Constraints.IMap)) {
            var map:haxe.Constraints.IMap<Dynamic, Dynamic> = cast target;
            return map.get(prop);
        } else if (Reflect.isObject(target)) {
            if (Reflect.hasField(target, prop)) {
                return Reflect.field(target, prop);
            } else {
                return Reflect.getProperty(target, prop);
            }
        }
        return null;
    }

    public function isTruthy(val:Dynamic):Bool {
        if (val == null) return false;
        if (Std.isOfType(val, Bool)) return cast val;
        if (Std.isOfType(val, Int) || Std.isOfType(val, Float)) return val != 0;
        if (Std.isOfType(val, String)) return (cast(val, String)).length > 0;
        if (Std.isOfType(val, Array)) return (cast(val, Array<Dynamic>)).length > 0;
        return true;
    }

    public function toArray(val:Dynamic):Array<Dynamic> {
        if (val == null) return [];
        if (Std.isOfType(val, Array)) return cast val;

        if (Reflect.isObject(val)) {
            var iterFn = Reflect.field(val, "iterator");
            if (iterFn != null && Reflect.isFunction(iterFn)) {
                var iter:Iterator<Dynamic> = Reflect.callMethod(val, iterFn, []);
                if (iter != null) {
                    var result = [];
                    while (iter.hasNext()) result.push(iter.next());
                    return result;
                }
            }
        }

        return [val];
    }
}
