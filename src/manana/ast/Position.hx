package manana.ast;

class Position {
    public final file:String;
    public final line:Int;
    public final column:Int;

    public function new(file:String, line:Int, column:Int) {
        this.file = file;
        this.line = line;
        this.column = column;
    }

    public function toString():String {
        return '${file}:${line}:${column}';
    }
}
