import markdown.AST;
import markdown.InlineParser;
import markdown.BlockParser;
import markdown.HtmlRenderer;
using StringTools;
using Lambda;

class Markdown
{
	#if sys
	public static function main()
	{
		var source = Sys.args()[0];
		
		try
		{
			var output = markdownToHtml(source);
			Sys.print(output);
		}
		catch (e:Dynamic)
		{
			Sys.print("Error: " + haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
		}
	}

	public static function colorize(source:String):String
	{
		var process = new sys.io.Process("neko", ["colorize.n", source]);
		return if (process.exitCode() == 0) process.stdout.readAll().toString();
		else "Error: Process error";
	}
	#else
	public static function colorize(source:String):String
	{
		return source;
	}
	#end

	public static function markdownToHtml(markdown:String):String
	{
		// create document
		var document = new Document();

		// replace windows line endings with unix, and split
		var lines = ~/\n\r/g.replace(markdown, '\n').split("\n");

		// parse ref links
		document.parseRefLinks(lines);

		// parse ast
		var blocks = document.parseLines(lines);
		return renderHtml(blocks);
	}

	public static function renderHtml(blocks:Array<Node>):String
	{
		return new HtmlRenderer().render(blocks);
	}
}

/**
	Maintains the context needed to parse a markdown document.
**/
class Document
{
	public var refLinks:Map<String, Link>;
	public var inlineSyntaxes:Array<InlineSyntax>;
	public var linkResolver:Resolver;

	public function new()
	{
		refLinks = new Map();
		inlineSyntaxes = [];
	}

	public function parseRefLinks(lines:Array<String>)
	{
		// This is a hideous regex. It matches:
		// [id]: http:foo.com "some title"
		// Where there may whitespace in there, and where the title may be in
		// single quotes, double quotes, or parentheses.
		var indent = '^[ ]{0,3}';	// Leading indentation.
		var id = '\\[([^\\]]+)\\]';	// Reference id in [brackets].
		var quote = '"[^"]+"';		// Title in "double quotes".
		var apos = "'[^']+'";		// Title in 'single quotes'.
		var paren = "\\([^)]+\\)";	// Title in (parentheses).
		var link = new EReg(
			'$indent$id:\\s+(\\S+)\\s*($quote|$apos|$paren|)\\s*$', '');
		// link = new EReg('\\[(google)\\]: (http://google.com)\\s*()','');

		for (i in 0...lines.length)
		{
			if (!link.match(lines[i])) continue;
			
			// Parse the link.
			var id = link.matched(1);
			var url = link.matched(2);
			var title = link.matched(3);
			// Sys.println(id);
			if (title == '')
			{
				// No title.
				title = null;
			}
			else
			{
				// Remove "", '', or ().
				title = title.substring(1, title.length - 1);
			}

			// References are case-insensitive.
			id = id.toLowerCase();
			refLinks.set(id, new Link(id, url, title));

			// Remove it from the output. We replace it with a blank line which 
			// will get consumed by later processing.
			lines[i] = '';
		}
	}

	/**
		Parse the given [lines] of markdown to a series of AST nodes.
	**/
	public function parseLines(lines:Array<String>):Array<Node>
	{
		var parser = new BlockParser(lines, this);
		var blocks = [];

		while (!parser.isDone)
		{
			for (syntax in BlockSyntax.syntaxes)
			{
				if (syntax.canParse(parser))
				{
					var block = syntax.parse(parser);
					if (block != null) blocks.push(block);
					break;
				}
			}
		}

		return blocks;
	}

	/**
		Takes a string of raw text and processes all inline markdown tags,
		returning a list of AST nodes. For example, given ``"*this **is** a*
		`markdown`"``, returns:
		`<em>this <strong>is</strong> a</em> <code>markdown</code>`.
	**/
	public function parseInline(text:String):Array<Node>
	{
		return new InlineParser(text, this).parse();
	}
}

class Link
{
	public var id(default, null):String;
	public var url(default, null):String;
	public var title(default, null):String;

	public function new(id:String, url:String, title:String)
	{
		this.id = id;
		this.url = url;
		this.title = title;
	}
}

typedef Resolver = String -> Node;
