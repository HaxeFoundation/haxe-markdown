import massive.munit.Assert;

class MarkdownTest
{
	function parses(markdown:String, html:String, ?pos:haxe.PosInfos)
	{
		Assert.areEqual(html, Markdown.markdownToHtml(markdown), pos);
	}

	@Test function wraps_in_paragraph() parses(
'Hello World',
'<p>Hello World</p>');

	@Test function wraps_in_paragraphs() parses(
'Hello World

Goodbye World.',
'<p>Hello World</p>
<p>Goodbye World.</p>');

	@Test function trims_paragraph_whitespace() parses(
'Hello World


Goodbye World.

',
'<p>Hello World</p>
<p>Goodbye World.</p>');

	@Test function converts_inline_emphasis() parses(
'*Hello* there _World_',
'<p><em>Hello</em> there <em>World</em></p>');

	@Test function does_not_convert_spaced_asterix() parses(
'*Hello * there',
'<p>*Hello * there</p>');

	@Test function does_not_convert_spaced_underscore() parses(
'_Hello _ there',
'<p>_Hello _ there</p>');

	@Test function converts_inline_strong_emphasis() parses(
'**Hello** there __World__',
'<p><strong>Hello</strong> there <strong>World</strong></p>');

	@Test function encodes_amp_enitity() parses(
'Me & you',
'<p>Me &amp; you</p>');

	@Test function leaves_existing_enitities() parses(
'Me &amp; you = &lt;3',
'<p>Me &amp; you = &lt;3</p>');

	@Test function encodes_lt_enitity() parses(
'Me <3 you',
'<p>Me &lt;3 you</p>');

	@Test function parses_inline_code() parses(
'This is `SomeCode`',
'<p>This is <code>SomeCode</code></p>');

	@Test function parses_inline_code_with_double_back_ticks() parses(
'This is ``SomeCode``',
'<p>This is <code>SomeCode</code></p>');

	@Test function parses_atx_headers() parses(
'# Heading 1
## Heading 2
### Heading 3',
'<h1>Heading 1</h1>
<h2>Heading 2</h2>
<h3>Heading 3</h3>');

	@Test function strips_hashes_trailing_atx_headers() parses(
'# Heading 1###
## Heading 2#
### Heading 3 #####',
'<h1>Heading 1</h1>
<h2>Heading 2</h2>
<h3>Heading 3</h3>');

	@Test function parses_setext_headers() parses(
'Heading 1
====
Heading 2
-',
'<h1>Heading 1</h1>
<h2>Heading 2</h2>');

	@Test function parses_indented_code_block() parses(
'Here is some code:

	var a = 2 + 3;',
'<p>Here is some code:</p>
<pre><code>var a = 2 + 3;
</code></pre>');

	@Test function parses_block_quote() parses(
'Quoth the Raven:

> Never more.',
'<p>Quoth the Raven:</p>
<blockquote>
<p>Never more.</p></blockquote>');

	@Test function parses_horizonal_rule() parses(
'Section 1

---

Section 2

* * *

Section 3',
'<p>Section 1</p>
<hr />
<p>Section 2</p>
<hr />
<p>Section 3</p>');

	@Test function parses_unordered_list() parses(
'Shopping list:

* Apples
* Oranges',
'<p>Shopping list:</p><ul><li>Apples</li><li>Oranges</li></ul>');

	@Test function parses_ordered_list() parses(
'Shopping list:

1. Apples
2. Oranges',
'<p>Shopping list:</p><ol><li>Apples</li><li>Oranges</li></ol>');

	@Test function parses_inline_link() parses(
'Click [here](http://google.com)',
'<p>Click <a href="http://google.com">here</a></p>');

	@Test function parses_reference_link() parses(
'Click [here][google]

[google]: http://google.com',
'<p>Click <a href="http://google.com">here</a></p>');

	@Test function parses_example()
	{
		var doc = Markdown.markdownToHtml(MarkdownExample.minimatch);
		Assert.isNotNull(doc);
	}

	@Test function leaves_inline_html() parses(
'Write <code>some code</code> or something.',
'<p>Write <code>some code</code> or something.</p>');

	@Test function leaves_inline_html_links() parses(
'A <a rel="custom" href="https://developer.mozilla.org/en/DOM/Document">link</a> to nowhere.',
'<p>A <a rel="custom" href="https://developer.mozilla.org/en/DOM/Document">link</a> to nowhere.</p>');

	@Test function parses_tables() parses(
'
| Head 1   |   Head 2  |   Head 3 |
|: ------- |: ------  :| ------- :|
| `Col 1`  |   Col 2   |    Col 3 |',
'<table><thead><th>Head 1</th><th align="center">Head 2</th><th align="right">Head 3</th></thead><tbody><tr><td><code>Col 1</code></td><td align="center">Col 2</td><td align="right">Col 3</td></tr></tbody></table>');

	@Test function parses_code_block_when_simn_adds_extra_whitespace_after_backticks() parses(
'```
foo;
``` 
text',
'<pre><code>foo;</code></pre>
<p>text</p>');

	@Test function no_greedy_inline_styles() parses(
'NEGATIVE_INFINITY or POSITIVE_INFINITY',
'<p>NEGATIVE_INFINITY or POSITIVE_INFINITY</p>');
}
