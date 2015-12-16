
haxe-markdown
=============
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

    git clone https://github.com/dpeek/haxe-markdown

Tell haxelib where your development copy of haxe-markdown is installed:

    haxelib dev markdown haxe-markdown/src

To return to release builds:

    haxelib dev markdown
