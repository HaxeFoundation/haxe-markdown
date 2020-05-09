
haxe-markdown
=============

[![Haxelib Version](https://badgen.net/haxelib/v/markdown)](https://lib.haxe.org/p/markdown)
[![Haxelib Downloads](https://badgen.net/haxelib/d/markdown?color=blue)](https://lib.haxe.org/p/markdown)
[![Haxelib License](https://badgen.net/haxelib/license/markdown)](LICENSE.md)

A Markdown parser in Haxe, ported from [dart-markdown](https://github.com/dpeek/dart-markdown).

### Introduction

_Markdown_, created by John Gruber, author of the [Daring Fireball blog](http://daringfireball.net). The original source of Markdown can be found at [Daring Fireball - Markdown](http://daringfireball.net/projects/markdown).

### Installation

    haxelib install markdown

###  Usage

```haxe
Markdown.markdownToHtml(markdown);
```

### Development Builds

Clone the repository:

    git clone https://github.com/HaxeFoundation/haxe-markdown

Tell haxelib where your development copy of haxe-markdown is installed:

    haxelib dev markdown haxe-markdown

To return to release builds:

    haxelib dev markdown
