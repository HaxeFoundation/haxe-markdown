package markdown;

import markdown.AST;
import Markdown;
using StringTools;
using Lambda;

/**
	Maintains the internal state needed to parse a series of lines into blocks
	of markdown suitable for further inline parsing.
**/
class BlockParser
{
	// the lines being parsed
	public var lines(default, null):Array<String>;

	// The markdown document this parser is parsing.
	public var document(default, null):Document;

	// Index of the current line.
	public var pos(default, null):Int;

	public function new(lines:Array<String>, document:Document)
	{
		this.lines = lines;
		this.document = document;
		this.pos = 0;
	}

	// Gets the current line.
	public var current(get, never):String;
	inline function get_current() return lines[pos];

	// Gets the line after the current one or `null` if there is none.
	public var next(get, never):String;
	function get_next()
	{
		// Don't read past the end.
		if (pos >= lines.length - 1) return null;
		return lines[pos + 1];
	}

	// Move to the next line.
	public function advance():Void pos++;

	// Are we there yet?
	public var isDone(get, never):Bool;
	inline function get_isDone() return pos >= lines.length;

	// Gets whether or not the current line matches the given pattern.
	public function matches(ereg:EReg):Bool
	{
		if (isDone) return false;
		return ereg.match(current);
	}

	// Gets whether or not the current line matches the given pattern.
	public function matchesNext(ereg:EReg):Bool
	{
		if (next == null) return false;
		return ereg.match(next);
	}
}

class BlockSyntax
{
	/**
		The line contains only whitespace or is empty.
	**/
	static var RE_EMPTY = new EReg('^([ \\t]*)$', '');

	/**
		A series of `=` or `-` (on the next line) define setext-style headers.
	**/
	static var RE_SETEXT = new EReg('^((=+)|(-+))$', '');

	/**
		Leading (and trailing) `#` define atx-style headers.
	**/
	static var RE_HEADER = new EReg('^(#{1,6})(.*?)#*$', '');

	/**
		The line starts with `>` with one optional space after.
	**/
	static var RE_BLOCKQUOTE = new EReg('^[ ]{0,3}>[ ]?(.*)$', '');

	/**
		A line indented four spaces. Used for code blocks and lists.
	**/
	static var RE_INDENT = new EReg('^(?:		|\\t)(.*)$', '');

	/**
		GitHub style triple quoted code block.
	**/
	static var RE_CODE = new EReg('^```(\\w*)\\s*$', '');

	/**
		Three or more hyphens, asterisks or underscores by themselves. Note that
		a line like `----` is valid as both HR and SETEXT. In case of a tie,
		SETEXT should win.
	**/
	static var RE_HR = new EReg('^[ ]{0,3}((-+[ ]{0,2}){3,}|(_+[ ]{0,2}){3,}|(\\*+[ ]{0,2}){3,})$', '');

	/**
		Really hacky way to detect block-level embedded HTML. Just looks for
		"<somename".
	**/
	static var RE_HTML = new EReg('^<[ ]*\\w+[ >]', '');

	/**
		A line starting with one of these markers: `-`, `*`, `+`. May have up to
		three leading spaces before the marker and any number of spaces or tabs
		after.
	**/
	static var RE_UL = new EReg('^[ ]{0,3}[*+-][ \\t]+(.*)$', '');
	
	/**
		A line starting with a number like `123.`. May have up to three leading
		spaces before the marker and any number of spaces or tabs after.
	**/
	static var RE_OL = new EReg('^[ ]{0,3}\\d+\\.[ \\t]+(.*)$', '');

	/**
		Gets the collection of built-in block parsers. To turn a series of lines
		into blocks, each of these will be tried in turn. Order matters here.
	**/
	public static var syntaxes(get, null):Array<BlockSyntax>;

	static function get_syntaxes():Array<BlockSyntax>
	{
		if (syntaxes == null)
		{
			syntaxes = [
				new EmptyBlockSyntax(),
				new BlockHtmlSyntax(),
				new SetextHeaderSyntax(),
				new HeaderSyntax(),
				new CodeBlockSyntax(),
				new GitHubCodeBlockSyntax(),
				new BlockquoteSyntax(),
				new HorizontalRuleSyntax(),
				new UnorderedListSyntax(),
				new OrderedListSyntax(),
				new TableSyntax(),
				new ParagraphSyntax()
			];
		}
		return syntaxes;
	}

	/**
		Gets whether or not [parser]'s current line should end the 
		previous block.
	**/
	public static function isAtBlockEnd(parser:BlockParser):Bool
	{
		if (parser.isDone) return true;
		for (syntax in syntaxes)
		{
			if (syntax.canParse(parser) && syntax.canEndBlock) return true;
		}
		return false;
	}

	public function new() {}

	/**
		Gets the regex used to identify the beginning of this block, if any.
	**/
	public var pattern(get, never):EReg;
	function get_pattern():EReg
	{
		return null;
	}

	public var canEndBlock(get, never):Bool;
	function get_canEndBlock():Bool
	{
		return true;
	}

	public function canParse(parser:BlockParser):Bool
	{
		return pattern.match(parser.current);
	}

	public function parse(parser:BlockParser):Node
	{
		return null;
	}

	public function parseChildLines(parser:BlockParser):Array<String>
	{
		var childLines = [];

		while (!parser.isDone)
		{
			if (!pattern.match(parser.current)) break;
			childLines.push(pattern.matched(1));
			parser.advance();
		}

		return childLines;
	}
}

class EmptyBlockSyntax extends BlockSyntax
{
	public function new() { super(); }

	override function get_pattern():EReg
	{
		return BlockSyntax.RE_EMPTY;
	}

	override public function parse(parser:BlockParser)
	{
		parser.advance();
		// Don't actually emit anything.
		return null;
	}
}

/**
	Parses setext-style headers.
**/
class SetextHeaderSyntax extends BlockSyntax
{
	public function new() { super(); }

	override public function canParse(parser:BlockParser)
	{
		// Note: matches *next* line, not the current one. We're looking for the
			// underlining after this line.
			return parser.matchesNext(BlockSyntax.RE_SETEXT);
	}

	override public function parse(parser:BlockParser)
	{
		var re = BlockSyntax.RE_SETEXT;
		re.match(parser.next);

		var tag = (re.matched(1).charAt(0) == '=') ? 'h1' : 'h2';
		var contents = parser.document.parseInline(parser.current);
		parser.advance();
		parser.advance();
		return new ElementNode(tag, contents);
	}
}

/**
	Parses atx-style headers: `## Header ##`.
**/
class HeaderSyntax extends BlockSyntax
{
	public function new() { super(); }

	override function get_pattern():EReg
	{
		return BlockSyntax.RE_HEADER;
	}

	override public function parse(parser:BlockParser)
	{
		pattern.match(parser.current);
		parser.advance();
		var level = pattern.matched(1).length;
		var contents = parser.document.parseInline(pattern.matched(2).trim());
		return new ElementNode('h$level', contents);
	}
}


// Parses email-style blockquotes: `> quote`.
class BlockquoteSyntax extends BlockSyntax
{
	override function get_pattern():EReg
	{
		return BlockSyntax.RE_BLOCKQUOTE;
	}

	override public function parse(parser:BlockParser):Node
	{
		var childLines = parseChildLines(parser);

		// Recursively parse the contents of the blockquote.
		var children = parser.document.parseLines(childLines);

		return new ElementNode('blockquote', children);
	}
}

// Parses preformatted code blocks that are indented four spaces.
class CodeBlockSyntax extends BlockSyntax
{
	override function get_pattern():EReg
	{
		return BlockSyntax.RE_INDENT;
	}

	override public function parseChildLines(parser:BlockParser):Array<String>
	{
		var childLines = [];

		while (!parser.isDone)
		{
			if (pattern.match(parser.current))
			{
				childLines.push(pattern.matched(1));
				parser.advance();
			}
			else
			{
				// If there's a codeblock, then a newline, then a codeblock, keep the
				// code blocks together.
				var nextMatch = parser.next != null ? pattern.match(parser.next) : false;

				if (parser.current.trim() == '' && nextMatch)
				{
					childLines.push('');
					childLines.push(pattern.matched(1));
					parser.advance();
					parser.advance();
				}
				else
				{
					break;
				}
			}
		}

		return childLines;
	}

	override public function parse(parser:BlockParser):Node
	{
		var childLines = parseChildLines(parser);

		// The Markdown tests expect a trailing newline.
		childLines.push('');

		// Escape the code.
		var escaped = childLines.join('\n').htmlEscape();

		return new ElementNode('pre', [ElementNode.text('code', escaped)]);
	}
}

// Parses preformatted code blocks between two ``` sequences.
class GitHubCodeBlockSyntax extends BlockSyntax
{
	override function get_pattern():EReg
	{
		return BlockSyntax.RE_CODE;
	}

	override public function parseChildLines(parser:BlockParser):Array<String>
	{
		var childLines = [];
		parser.advance();
		
		while (!parser.isDone)
		{
			if (!pattern.match(parser.current)) {
				childLines.push(parser.current);
				parser.advance();
			} else {
				parser.advance();
				break;
			}
		}
		return childLines;
	}

	override public function parse(parser:BlockParser):Node
	{
		// Get the syntax identifier, if there is one.
		// pattern.match(parser.current);
		var syntax = pattern.matched(1);
		var childLines = parseChildLines(parser);
		
		return new ElementNode('pre', [ElementNode.text('code', childLines.join('\n').htmlEscape())]);
	}
}

// Parses horizontal rules like `---`, `_ _ _`, `*	*	*`, etc.
class HorizontalRuleSyntax extends BlockSyntax
{
	override function get_pattern():EReg
	{
		return BlockSyntax.RE_HR;
	}

	override public function parse(parser:BlockParser):Node
	{
		parser.advance();
		return ElementNode.empty('hr');
	}
}

// Parses inline HTML at the block level. This differs from other markdown
// implementations in several ways:
//
// 1.	This one is way way WAY simpler.
// 2.	All HTML tags at the block level will be treated as blocks. If you
//		 start a paragraph with `<em>`, it will not wrap it in a `<p>` for you.
//		 As soon as it sees something like HTML, it stops mucking with it until
//		 it hits the next block.
// 3.	Absolutely no HTML parsing or validation is done. We're a markdown
//		 parser not an HTML parser!
class BlockHtmlSyntax extends BlockSyntax
{
	override function get_pattern():EReg
	{
		return BlockSyntax.RE_HTML;
	}

	override function get_canEndBlock() return false;

	override public function parse(parser:BlockParser):Node
	{
		var childLines = [];

		// Eat until we hit a blank line.
		while (!parser.isDone && !parser.matches(BlockSyntax.RE_EMPTY))
		{
			childLines.push(parser.current);
			parser.advance();
		}

		return new TextNode(childLines.join('\n'));
	}
}

class ListItem
{
	public var forceBlock:Bool = false;
	public var lines(default, null):Array<String>;

	public function new(lines:Array<String>)
	{
		this.lines = lines;
	}
}

// Parses paragraphs of regular text.
class ParagraphSyntax extends BlockSyntax
{
	override function get_canEndBlock() return false;

	override public function canParse(parser:BlockParser):Bool
	{
		return true;
	}

	override public function parse(parser:BlockParser):Node
	{
		var childLines = [];

		// Eat until we hit something that ends a paragraph.
		while (!BlockSyntax.isAtBlockEnd(parser))
		{
			childLines.push(parser.current);
			parser.advance();
		}

		var contents = parser.document.parseInline(childLines.join('\n'));
		return new ElementNode('p', contents);
	}
}

// Base class for both ordered and unordered lists.
class ListSyntax extends BlockSyntax
{
	override function get_canEndBlock()
	{
		return false;
	}

	public var listTag(default, null):String;

	public function new(listTag:String)
	{
		super();
		this.listTag = listTag;
	}

	override public function parse(parser:BlockParser):Node
	{
		var items = [];
		var childLines = [];

		function endItem()
		{
			if (childLines.length > 0)
			{
				items.push(new ListItem(childLines));
				childLines = [];
			}
		}

		var match:EReg;
		function tryMatch(pattern:EReg) {
			match = pattern;
			return pattern.match(parser.current);
		}

		var afterEmpty = false;
		while (!parser.isDone)
		{
			if (tryMatch(BlockSyntax.RE_EMPTY))
			{
				// Add a blank line to the current list item.
				childLines.push('');
			}
			else if (tryMatch(BlockSyntax.RE_UL) || tryMatch(BlockSyntax.RE_OL))
			{
				// End the current list item and start a new one.
				endItem();
				childLines.push(match.matched(1));
			}
			else if (tryMatch(BlockSyntax.RE_INDENT))
			{
				// Strip off indent and add to current item.
				childLines.push(match.matched(1));
			}
			else if (BlockSyntax.isAtBlockEnd(parser))
			{
				// Done with the list.
				break;
			}
			else
			{
				// Anything else is paragraph text or other stuff that can be in a list
				// item. However, if the previous item is a blank line, this means we're
				// done with the list and are starting a new top-level paragraph.
				if ((childLines.length > 0) && (childLines[childLines.length-1] == '')) break;
				childLines.push(parser.current);
			}
			parser.advance();
		}

		endItem();

		// Markdown, because it hates us, specifies two kinds of list items. If you
		// have a list like:
		//
		// * one
		// * two
		//
		// Then it will insert the conents of the lines directly in the <li>, like:
		// <ul>
		//	 <li>one</li>
		//	 <li>two</li>
		// <ul>
		//
		// If, however, there are blank lines between the items, each is wrapped in
		// paragraphs:
		//
		// * one
		//
		// * two
		//
		// <ul>
		//	 <li><p>one</p></li>
		//	 <li><p>two</p></li>
		// <ul>
		//
		// In other words, sometimes we parse the contents of a list item like a
		// block, and sometimes line an inline. The rules our parser implements are:
		//
		// - If it has more than one line, it's a block.
		// - If the line matches any block parser (BLOCKQUOTE, HEADER, HR, INDENT,
		//	 UL, OL) it's a block. (This is for cases like "* > quote".)
		// - If there was a blank line between this item and the previous one, it's
		//	 a block.
		// - If there was a blank line between this item and the next one, it's a
		//	 block.
		// - Otherwise, parse it as an inline.

		// Remove any trailing empty lines and note which items are separated by
		// empty lines. Do this before seeing which items are single-line so that
		// trailing empty lines on the last item don't force it into being a block.
		for (i in 0...items.length)
		{
			var len = items[i].lines.length;
			for (jj in 1...len+1)
			{
				var j = len - jj;
				if (BlockSyntax.RE_EMPTY.match(items[i].lines[j]))
				{
					// Found an empty line. Item and one after it are blocks.
					if (i < items.length - 1)
					{
						items[i].forceBlock = true;
						items[i + 1].forceBlock = true;
					}
					items[i].lines.pop();
				}
				else
				{
					break;
				}
			}
		}

		// Convert the list items to Nodes.
		var itemNodes:Array<Node> = [];
		for (item in items)
		{
			var blockItem = item.forceBlock || (item.lines.length > 1);

			// See if it matches some block parser.
			var blocksInList = [
				BlockSyntax.RE_BLOCKQUOTE,
				BlockSyntax.RE_HEADER,
				BlockSyntax.RE_HR,
				BlockSyntax.RE_INDENT,
				BlockSyntax.RE_UL,
				BlockSyntax.RE_OL
			];

			if (!blockItem)
			{
				for (pattern in blocksInList)
				{
					if (pattern.match(item.lines[0]))
					{
						blockItem = true;
						break;
					}
				}
			}

			// Parse the item as a block or inline.
			if (blockItem)
			{
				// Block list item.
				var children = parser.document.parseLines(item.lines);
				itemNodes.push(new ElementNode('li', children));
			}
			else
			{
				// Raw list item.
				var contents = parser.document.parseInline(item.lines[0]);
				itemNodes.push(new ElementNode('li', contents));
			}
		}

		return new ElementNode(listTag, itemNodes);
	}
}

// Parses unordered lists.
class UnorderedListSyntax extends ListSyntax
{
	override function get_pattern():EReg
	{
		return BlockSyntax.RE_UL;
	}

	public function new()
	{
		super('ul');
	}
}

// Parses ordered lists.
class OrderedListSyntax extends ListSyntax
{
	override function get_pattern():EReg
	{
		return BlockSyntax.RE_OL;
	}

	public function new()
	{
		super('ol');
	}
}

class TableSyntax extends BlockSyntax
{
	static var TABLE_PATTERN = new EReg('^(.+? +:?\\|:? +)+(.+)$', '');
	static var CELL_PATTERN = new EReg('(\\|)?([^\\|]+)(\\|)?', 'g');

	public function new()
	{
		super();
	}

	override function get_pattern():EReg
	{
		return TABLE_PATTERN;
	}

	override function get_canEndBlock()
	{
		return false;
	}
  
	override public function parse(parser:BlockParser):Node
	{
		var lines = [];

		while (!parser.isDone && parser.matches(TABLE_PATTERN))
		{
			lines.push(parser.current);
			parser.advance();
		}
		
		var heads:Array<Node> = [];
		var rows:Array<Node> = [];
		var align = [];

		var headLine = lines.shift();
		var alignLine = lines.shift();

		// get alignment from separator line
		var aligns = [];
		CELL_PATTERN.map(alignLine, function(e){
			var text = e.matched(2);
			var align = text.charAt(0) == ':' 
				? text.charAt(text.length - 1) == ':' ? 'center' : 'left'
				: text.charAt(text.length - 1) == ':' ? 'right' : 'left';
			aligns.push(align);
			return '';
		});
		
		// create thead
		var index = 0;
		CELL_PATTERN.map(headLine, function(e){
			var text = StringTools.trim(e.matched(2));
			var cell = new ElementNode('th', parser.document.parseInline(text));
			if (aligns[index] != 'left') cell.attributes.set('align', aligns[index]);
			heads.push(cell);
			index += 1;
			return '';
		});

		for (line in lines)
		{
			var cols:Array<Node> = [];
			rows.push(new ElementNode('tr', cols));

			var index = 0;
			CELL_PATTERN.map(line, function(e){
				var text = StringTools.trim(e.matched(2));
				var cell = new ElementNode('td', parser.document.parseInline(text));
				if (aligns[index] != 'left') cell.attributes.set('align', aligns[index]);
				cols.push(cell);
				index += 1;
				return '';
			});
		}

		return new ElementNode('table', [
			new ElementNode('thead', heads), 
			new ElementNode('tbody', rows)
		]);
	}
}
