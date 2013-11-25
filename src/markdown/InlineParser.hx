package markdown;

import markdown.AST;
import Markdown;
using StringTools;
using Lambda;

/**
	Maintains the internal state needed to parse inline span elements in
	markdown.
**/
class InlineParser
{
	static var defaultSyntaxes = [
		// This first regexp matches plain text to accelerate parsing.	It must
		// be written so that it does not match any prefix of any following
		// syntax.	Most markdown is plain text, so it is faster to match one
		// regexp per 'word' rather than fail to match all the following regexps
		// at each non-syntax character position.	It is much more important
		// that the regexp is fast than complete (for example, adding grouping
		// is likely to slow the regexp down enough to negate its benefit).
		// Since it is purely for optimization, it can be removed for debugging.

		// TODO(amouravski): this regex will glom up any custom syntaxes unless
		// they're at the beginning.
		new TextSyntax('\\s*[A-Za-z0-9]+'),

		// The real syntaxes.

		new AutolinkSyntax(),
		new LinkSyntax(),
		// "*" surrounded by spaces is left alone.
		new TextSyntax(' \\* '),
		// "_" surrounded by spaces is left alone.
		new TextSyntax(' _ '),
		// Leave already-encoded HTML entities alone. Ensures we don't turn
		// "&amp;" into "&amp;amp;"
		new TextSyntax('&[#a-zA-Z0-9]*;'),
		// Encode "&".
		new TextSyntax('&', '&amp;'),
		// Leave HTML as is.
		new TextSyntax('</?\\w+.*?>'),
		// Encode "<". (Why not encode ">" too? Gruber is toying with us.)
		new TextSyntax('<', '&lt;'),
		// Parse "**strong**" tags.
		new TagSyntax('\\*\\*', 'strong'),
		// Parse "__strong__" tags.
		new TagSyntax('__', 'strong'),
		// Parse "*emphasis*" tags.
		new TagSyntax('\\*', 'em'),
		// Parse "_emphasis_" tags.
		new TagSyntax('\\b_', 'em', '_\\b'),
		// Parse inline code within double backticks: "``code``".
		new CodeSyntax('``\\s?((?:.|\\n)*?)\\s?``'),
		// Parse inline code within backticks: "`code`".
		new CodeSyntax('`([^`]*)`')
		// We will add the LinkSyntax once we know about the specific link resolver.
	];

	// The string of markdown being parsed.
	public var source(default, null):String;

	// The markdown document this parser is parsing.
	public var document(default, null):Document;

	public var syntaxes(default, null):Array<InlineSyntax>;

	// The current read position.
	public var pos(default, null):Int = 0;

	// Starting position of the last unconsumed text.
	public var start:Int = 0;

	public var stack(default, null):Array<TagState>;

	public function new(source:String, document:Document)
	{
		this.source = source;
		this.document = document;
		stack = [];

		// User specified syntaxes will be the first syntaxes to be evaluated.
		if (document.inlineSyntaxes != null)
		{
			syntaxes = [];
			for (syntax in document.inlineSyntaxes)
				syntaxes.push(syntax);
			for (syntax in defaultSyntaxes)
				syntaxes.push(syntax);
		}
		else
		{
			syntaxes = defaultSyntaxes;
		}

		// Custom link resolver goes after the generic text syntax.
		syntaxes.insert(1, new LinkSyntax(document.linkResolver));
	}
	
	public function parse():Array<Node>
	{
		// Make a fake top tag to hold the results.
		stack.push(new TagState(0, 0, null));

		while (!isDone)
		{
			var matched = false;

			// See if any of the current tags on the stack match. We don't allow tags
			// of the same kind to nest, so this takes priority over other possible // matches.
			for (i in 1...stack.length)
			{
				if (stack[stack.length - i].tryMatch(this))
				{
					matched = true;
					break;
				}
			}
			
			if (matched) continue;

			// See if the current text matches any defined markdown syntax.
			for (syntax in syntaxes)
			{
				if (syntax.tryMatch(this))
				{
					matched = true;
					break;
				}
			}

			if (matched) continue;

			// If we got here, it's just text.
			advanceBy(1);
		}

		// Unwind any unmatched tags and get the results.
		return stack[0].close(this);
	}

	public function writeText()
	{
		writeTextRange(start, pos);
		start = pos;
	}

	public function writeTextRange(start:Int, end:Int)
	{
		if (end > start)
		{
			var text = source.substring(start, end);
			var nodes = stack[stack.length - 1].children;

			// If the previous node is text too, just append.
			if ((nodes.length > 0) && (Std.is(nodes[nodes.length - 1], TextNode)))
			{
				var lastNode:TextNode = cast nodes[nodes.length - 1];
				var newNode = new TextNode('${lastNode.text}$text');
				nodes[nodes.length - 1] = newNode;
			}
			else
			{
				nodes.push(new TextNode(text));
			}
		}
	}

	public function addNode(node:Node)
	{
		stack[stack.length - 1].children.push(node);
	}

	// TODO(rnystrom): Only need this because RegExp doesn't let you start
	// searching from a given offset.
	public var currentSource(get, never):String;
	function get_currentSource() return source.substring(pos, source.length);

	public var isDone(get, never):Bool;
	function get_isDone() return pos == source.length;

	public function advanceBy(length:Int)
	{
		pos += length;
	}

	public function consume(length:Int)
	{
		pos += length;
		start = pos;
	}
}

/**
	Represents one kind of markdown tag that can be parsed.
**/
class InlineSyntax
{
	var pattern:EReg;

	public function new(pattern:String)
	{
		this.pattern = new EReg(pattern, 'm');
	}

	public function tryMatch(parser:InlineParser):Bool
	{
		if (pattern.match(parser.currentSource) && (pattern.matchedPos().pos == 0))
		{
			// Write any existing plain text up to this point.
			parser.writeText();

			if (onMatch(parser))
			{
				parser.consume(pattern.matched(0).length);
			}

			return true;
		}
		return false;
	}

	function onMatch(parser:InlineParser):Bool
	{
		return false;
	}
}

/**
	Matches stuff that should just be passed through as straight text.
**/
class TextSyntax extends InlineSyntax
{
	var substitute:String;

	public function new(pattern:String, ?substitute:String)
	{
		super(pattern);
		this.substitute = substitute;
	}

	override function onMatch(parser:InlineParser):Bool
	{
		if (substitute == null)
		{
			// Just use the original matched text.
			parser.advanceBy(pattern.matched(0).length);
			return false;
		}

		// Insert the substitution.
		parser.addNode(new TextNode(substitute));
		return true;
	}
}

/**
	Matches autolinks like `<http://foo.com>`.
**/
class AutolinkSyntax extends InlineSyntax
{
	public function new()
	{
		// TODO(rnystrom): Make case insensitive.
		super('<((http|https|ftp)://[^>]*)>');
	}

	override function onMatch(parser:InlineParser):Bool
	{
		var url = pattern.matched(1);

		var anchor = ElementNode.text('a', url.htmlEscape());
		anchor.attributes.set('href', url);
		parser.addNode(anchor);

		return true;
	}
}

/**
	Matches syntax that has a pair of tags and becomes an element, like `*` for
	`<em>`. Allows nested tags.
**/
class TagSyntax extends InlineSyntax
{
	public var endPattern(default, null):EReg;
	public var tag(default, null):String;

	public function new(pattern:String, ?tag:String, ?end:String)
	{
		super(pattern);
		this.tag = tag;
		this.endPattern = new EReg((end == null) ? pattern : end, 'm');
	}
	
	override function onMatch(parser:InlineParser):Bool
	{
		parser.stack.push(new TagState(parser.pos, 
			parser.pos + pattern.matched(0).length, this));
		return true;
	}

	public function onMatchEnd(parser:InlineParser, state:TagState):Bool
	{
		parser.addNode(new ElementNode(tag, state.children));
		return true;
	}
}

/**
	Matches inline links like `[blah] [id]` and `[blah] (url)`.
**/
class LinkSyntax extends TagSyntax
{
	var linkResolver:Resolver;

	// The regex for the end of a link needs to handle both reference style and
	// inline styles as well as optional titles for inline links. To make that
	// a bit more palatable, this breaks it into pieces.
	static var linkPattern = '\\](?:('+
		'\\s?\\[([^\\]]*)\\]'+
		'|'+
		'\\s?\\(([^ )]+)(?:[ ]*"([^"]+)"|)\\)'+
		')|)';

	// The groups matched by this are:
	// 1: Will be non-empty if it's either a ref or inline link. Will be empty
	//    if it's just a bare pair of square brackets with nothing after them.
	// 2: Contains the id inside [] for a reference-style link.
	// 3: Contains the URL for an inline link.
	// 4: Contains the title, if present, for an inline link.
	public function new(?linkResolver:Resolver)
	{
		super('\\[', null, linkPattern);
		this.linkResolver = linkResolver;
	}

	override function onMatchEnd(parser:InlineParser, state:TagState):Bool
	{
		var url:String;
		var title:String;

		// If we didn't match refLink or inlineLink, then it means there was
		// nothing after the first square bracket, so it isn't a normal markdown
		// link at all. Instead, we allow users of the library to specify a special
		// resolver function ([linkResolver]) that may choose to handle
		// this. Otherwise, it's just treated as plain text.
		if ((endPattern.matched(1) == null) || (endPattern.matched(1) == ''))
		{
			if (linkResolver == null) return false;

			// Only allow implicit links if the content is just text.
			// TODO(rnystrom): Do we want to relax this?
			if (state.children.length != 1) return false;
			if (!Std.is(state.children[0], TextNode)) return false;

			var link:TextNode = cast state.children[0];

			// See if we have a resolver that will generate a link for us.
			var node = linkResolver(link.text);
			if (node == null) return false;

			parser.addNode(node);
			return true;
		}

		if ((endPattern.matched(3) != null) && (endPattern.matched(3) != '')) {
			// Inline link like [foo](url).
			url = endPattern.matched(3);
			title = endPattern.matched(4);

			// For whatever reason, markdown allows angle-bracketed URLs here.
			if (url.startsWith('<') && url.endsWith('>'))
			{
				url = url.substring(1, url.length - 1);
			}
		}
		else
		{
			// Reference link like [foo] [bar].
			var id = endPattern.matched(2);
			if (id == '')
			{
				// The id is empty ("[]") so infer it from the contents.
				id = parser.source.substring(state.startPos + 1, parser.pos);
			}

			// References are case-insensitive.
			id = id.toLowerCase();

			// Look up the link.
			var link = parser.document.refLinks.get(id);

			// If it's an unknown link just emit plaintext.
			if (link == null) return false;

			url = link.url;
			title = link.title;
		}

		var anchor = new ElementNode('a', state.children);
		anchor.attributes.set('href', url.htmlEscape());
		
		if ((title != null) && (title != ''))
		{
			anchor.attributes.set('title', title.htmlEscape());
		}

		parser.addNode(anchor);
		return true;
	}
}

// Matches backtick-enclosed inline code blocks.
class CodeSyntax extends InlineSyntax
{
	public function new(pattern:String)
	{
		super(pattern);
	}
	
	override function onMatch(parser:InlineParser):Bool
	{
		parser.addNode(ElementNode.text('code', pattern.matched(1).htmlEscape()));
		return true;
	}
}

// Keeps track of a currently open tag while it is being parsed. The parser
// maintains a stack of these so it can handle nested tags.
class TagState
{
	// The point in the original source where this tag started.
	public var startPos(default, null):Int;

	// The point in the original source where open tag ended.
	public var endPos(default, null):Int;

	// The syntax that created this node.
	public var syntax(default, null):TagSyntax;

	// The children of this node. Will be `null` for text nodes.
	public var children(default, null):Array<Node>;

	public function new(startPos:Int, endPos:Int, syntax:TagSyntax)
	{
		this.startPos = startPos;
		this.endPos = endPos;
		this.syntax = syntax;
		children = [];
	}
	
	// Attempts to close this tag by matching the current text against its end
	// pattern.
	public function tryMatch(parser:InlineParser):Bool
	{
		if (syntax.endPattern.match(parser.currentSource) 
			&& (syntax.endPattern.matchedPos().pos == 0))
		{
			// Close the tag.
			close(parser);
			return true;
		}

		return false;
	}

	// Pops this tag off the stack, completes it, and adds it to the output.
	// Will discard any unmatched tags that happen to be above it on the stack.
	// If this is the last node in the stack, returns its children.
	public function close(parser:InlineParser):Array<Node>
	{
		// If there are unclosed tags on top of this one when it's closed, that
		// means they are mismatched. Mismatched tags are treated as plain text in
		// markdown. So for each tag above this one, we write its start tag as text
		// and then adds its children to this one's children.
		var index = parser.stack.indexOf(this);

		// Remove the unmatched children.
		var unmatchedTags = //parser.stack.slice(index + 1);
			parser.stack.splice(index + 1, parser.stack.length-index);

		// Flatten them out onto this tag.
		for (unmatched in unmatchedTags)
		{
			// Write the start tag as text.
			parser.writeTextRange(unmatched.startPos, unmatched.endPos);

			// Bequeath its children unto this tag.
			for (child in unmatched.children)
				children.push(child);
		}

		// Pop this off the stack.
		parser.writeText();
		parser.stack.pop();

		// If the stack is empty now, this is the special "results" node.
		if (parser.stack.length == 0) return children;

		// We are still parsing, so add this to its parent's children.
		if (syntax.onMatchEnd(parser, this))
		{
			parser.consume(syntax.endPattern.matched(0).length);
		}
		else
		{
			// Didn't close correctly so revert to text.
			parser.start = startPos;
			parser.advanceBy(syntax.endPattern.matched(0).length);
		}

		return null;
	}
}
