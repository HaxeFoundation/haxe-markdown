import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;
using StringTools;
using haxe.io.Path;

class TestSuiteBuilder {
	public static function build( testDir:String ):Array<Field> {
		var fields = Context.getBuildFields();
		var spec = sys.io.File.getContent('spec.txt');

		var marker = ~/^\.$/gm;
		var test:{name:String, ?markdown:String, ?html:String} = null;
		var tests = [];
		var index = 0;
		while (marker.matchSub(spec, index))
		{
			var pos = marker.matchedPos();
			var text = spec.substring(index, pos.pos);

			if (test == null)
			{
				var num = tests.length + 1;
				test = {name:'test$num'};
				tests.push(test);
				index = pos.pos + pos.len;
				continue;
			}

			if (test.markdown == null)
			{
				test.markdown = StringTools.replace(text, '→', '\t');
			}
			else if (test.html == null)
			{
				test.html = text;
				test = null;
			}

			index = pos.pos + pos.len;
		}

		var pos = Context.currentPos();
		for (test in tests)
		{
			var field = {
				name: test.name,
				pos: pos,
				meta: [{ name: "Test", pos: pos, params: null }],
				kind: FFun({
					ret:null,
					params:[],
					args:[],
					expr: macro parses($v{test.markdown},$v{test.html},$v{test.name})
				}),
				doc: null,
				access: [APublic]
			};
			fields.push(field);
		}

		// var dir = Context.resolvePath(testDir);
		// var files = FileSystem.readDirectory(dir);
		// var p = Context.currentPos();
		// for (f in files) {
		// 	if (f.extension()=="md") {
		// 		var testName = f.withoutExtension();
		// 		var inFile = dir.addTrailingSlash()+f;
		// 		var outFile = dir.addTrailingSlash()+testName+'.out';
		// 		if (FileSystem.exists(outFile)) {
		// 			var input = File.getContent(inFile);
		// 			var expected = File.getContent(outFile);
		// 			var fnName = "test_"+testName.replace("-","_");
		// 			var field = {
		// 				name: fnName,
		// 				pos: p,
		// 				meta: [{ name: "Test", pos: p, params: null }],
		// 				kind: FFun({
		// 					ret:null,
		// 					params:[],
		// 					args:[],
		// 					expr: macro parses($v{input},$v{expected},$v{testName})
		// 				}),
		// 				doc: null,
		// 				access: [APublic]
		// 			};
		// 			fields.push(field);
		// 		}
		// 	}
		// }
		return fields;
	}
}