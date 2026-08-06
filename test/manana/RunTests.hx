package manana;

class RunTests {
    static function main():Void {
        Sys.println("=== Running Manana Test Suite ===");

        var astTests = new TestAst();
        astTests.runAll();

        var lexerTests = new TestLexer();
        lexerTests.runAll();

        var parserTests = new TestParser();
        parserTests.runAll();

        var htmlCompilerTests = new TestHtmlCompiler();
        htmlCompilerTests.runAll();

        Sys.println('\nResults: ${Assert.passedCount} passed, ${Assert.failedCount} failed.');

        if (Assert.failedCount > 0) {
            Sys.exit(1);
        }
    }
}
