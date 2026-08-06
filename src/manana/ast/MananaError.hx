package manana.ast;

class MananaError {
    public final message:String;
    public final pos:Position;

    public function new(message:String, pos:Position) {
        this.message = message;
        this.pos = pos;
    }

    public function toString():String {
        return '[Manana Syntax Error] ${message} at ${pos.toString()}';
    }
}
