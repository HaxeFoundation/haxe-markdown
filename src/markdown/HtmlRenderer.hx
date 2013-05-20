package markdown;

import markdown.AST;

/**
	Translates a parsed AST to HTML.
**/
class HtmlRenderer implements NodeVisitor
{
	static var BLOCK_TAGS = new EReg('blockquote|h1|h2|h3|h4|h5|h6|hr|p|pre', '');

	var buffer:StringBuf;

	public function new() {}

	public function render(nodes:Array<Node>):String
	{
		buffer = new StringBuf();
		for (node in nodes) node.accept(this);
		return buffer.toString();
	}

	public function visitText(text:TextNode):Void
	{
		buffer.add(text.text);
	}

	public function visitElementBefore(element:ElementNode):Bool
	{
		// Hackish. Separate block-level elements with newlines.
		if (buffer.toString() != "" && BLOCK_TAGS.match(element.tag))
		{
			buffer.add('\n');
		}

		buffer.add('<${element.tag}');

		// Sort the keys so that we generate stable output.
		// TODO(rnystrom): This assumes keys returns a fresh mutable
		// collection.
		var attributeNames = [for (k in element.attributes.keys()) k];
		attributeNames.sort(Reflect.compare);
		for (name in attributeNames)
		{
			buffer.add(' $name="${element.attributes.get(name)}"');
		}

		if (element.isEmpty())
		{
			// Empty element like <hr/>.
			buffer.add(' />');
			return false;
		}
		else
		{
			buffer.add('>');
			return true;
		}
	}

	public function visitElementAfter(element:ElementNode):Void
	{
		buffer.add('</${element.tag}>');
	}
}
