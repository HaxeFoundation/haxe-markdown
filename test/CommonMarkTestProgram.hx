class CommonMarkTestProgram {
    static function main() {
        var source = Sys.stdin().readAll().toString();
        var output = Markdown.markdownToHtml(source);
        Sys.stdout().writeString(output);
    }
}
