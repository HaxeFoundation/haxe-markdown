package markdown;

/**
	Base class for any AST item. Roughly corresponds to Node in the DOM. Will
	be either an ElementNode or TextNode.
**/
interface Node
{
	function accept(visitor:NodeVisitor):Void;
}

/**
	Visitor pattern for the AST. Renderers or other AST transformers should
	implement this.
**/
interface NodeVisitor
{
	/**
		Called when a TextNode has been reached.
	**/
	function visitText(text:TextNode):Void;

	/**
		Called when an ElementNode has been reached, before its children have been
		visited. Return `false` to skip its children.
	**/
	function visitElementBefore(element:ElementNode):Bool;

	/**
		Called when an ElementNode has been reached, after its children have been
		visited. Will not be called if [visitElementBefore] returns `false`.
	**/
	function visitElementAfter(element:ElementNode):Void;
}

/**
	A named tag that can contain other nodes.
**/
class ElementNode implements Node
{
	public static function empty(tag:String):ElementNode
	{
		return new ElementNode(tag, null);
	}

	public static function withTag(tag:String):ElementNode
	{
		return new ElementNode(tag, []);
	}

	public static function text(tag:String, text:String):ElementNode
	{
		return new ElementNode(tag, [new TextNode(text)]);
	}

	public var tag(default, null):String;
	public var children(default, null):Array<Node>;
	public var attributes(default, null):Map<String, String>;

	public function new(tag:String, children:Array<Node>)
	{
		this.tag = tag;
		this.children = children;
		this.attributes = new Map();
	}

	inline public function isEmpty():Bool
	{
		return children == null;
	}

	public function accept(visitor:NodeVisitor):Void
	{
		if (visitor.visitElementBefore(this))
		{
			for (child in children) child.accept(visitor);
			visitor.visitElementAfter(this);
		}
	}
}

/**
	A plain text element.
**/
class TextNode implements Node
{
	public var text(default, null):String;

	public function new(text:String) this.text = text;

	public function accept(visitor:NodeVisitor):Void
	{
		visitor.visitText(this);
	}
}
