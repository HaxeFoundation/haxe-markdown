import massive.munit.Assert;
using StringTools;

@:build(TestSuiteBuilder.build("markdown-testsuite/tests/"))
class MarkdownCoreTest
{
	public static function parses(markdown:String, expected:String, testName:String, ?pos:haxe.PosInfos)
	{
		var actual = Markdown.markdownToHtml(markdown);
		if (actual!=expected) {
			var message = '\n\n-----\n';
			message += 'For test $testName:';
			message += '\n  Markdown:\n    ';
			message += markdown.replace("\n","\n    ");
			message += '\n  Should generate:\n    ';
			message += expected.replace("\n","\n    ");
			message += '\n  But instead generated:\n    ';
			message += actual.replace("\n","\n    ");
			message += '\n';

			Assert.fail( message, pos );
		}
	}
}
