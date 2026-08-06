package manana;

class Assert {
    public static var passedCount:Int = 0;
    public static var failedCount:Int = 0;

    public static function equals<T>(expected:T, actual:T, ?pos:haxe.PosInfos):Void {
        if (expected == actual) {
            passedCount++;
        } else {
            failedCount++;
            Sys.println('  [FAIL] ${pos.fileName}:${pos.lineNumber} - Expected "$expected", got "$actual"');
        }
    }

    public static function isTrue(condition:Bool, ?pos:haxe.PosInfos):Void {
        if (condition) {
            passedCount++;
        } else {
            failedCount++;
            Sys.println('  [FAIL] ${pos.fileName}:${pos.lineNumber} - Expected true, got false');
        }
    }

    public static function isFalse(condition:Bool, ?pos:haxe.PosInfos):Void {
        if (!condition) {
            passedCount++;
        } else {
            failedCount++;
            Sys.println('  [FAIL] ${pos.fileName}:${pos.lineNumber} - Expected false, got true');
        }
    }
}
