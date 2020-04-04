import massive.munit.Assert;

using StringTools;

@:build(TestSuiteBuilder.build("markdown-testsuite/tests/"))
class MarkdownCoreTest {
	// whitespace between tags can go right to hell
	static var NO_TIME_FOR = ~/(^|>)([\s\n]+)(<|$)/gm;

	static function clean(str:String) {
		return NO_TIME_FOR.map(str, function(e) return e.matched(1) + e.matched(3));
	}

	public static function parses(markdown:String, expected:String, testName:String, ?pos:haxe.PosInfos) {
		var actual = Markdown.markdownToHtml(markdown);

		expected = clean(expected);
		actual = clean(actual);

		if (actual != expected) {
			var message = '\n\n-----\n';
			message += 'For test $testName:';
			message += '\n  Markdown:\n    ';
			message += markdown.replace("\n", "\n    ");
			message += '\n  Should generate:\n';
			message += expected;
			message += '\n  But instead generated:\n';
			message += actual;
			message += '\n';

			Assert.fail(message, pos);
		}
	}
}
