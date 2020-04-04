import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;

using StringTools;
using haxe.io.Path;

class TestSuiteBuilder {
	public static function build(dir:String):Array<Field> {
		var fields = Context.getBuildFields();
		var files = FileSystem.readDirectory(dir);
		var p = Context.currentPos();
		for (f in files) {
			if (f.extension() == "md") {
				var testName = f.withoutExtension();
				var inFile = dir.addTrailingSlash() + f;
				var outFile = dir.addTrailingSlash() + testName + '.out';
				if (FileSystem.exists(outFile)) {
					var input = File.getContent(inFile);
					var expected = File.getContent(outFile);
					var fnName = "test_" + testName.replace("-", "_").replace("+", "_");
					var field = {
						name: fnName,
						pos: p,
						meta: [{name: "Test", pos: p, params: null}],
						kind: FFun({
							ret: null,
							params: [],
							args: [],
							expr: macro parses($v{input}, $v{expected}, $v{testName})
						}),
						doc: null,
						access: [APublic]
					};
					fields.push(field);
				}
			}
		}
		return fields;
	}
}
