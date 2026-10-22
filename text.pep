## Styled text: a `Span` is a run of text in one style, a `Line` a row of
## spans, and a `Text` a stack of lines. Each converts from a `String`, so a
## widget that takes a `Text` takes a plain string too.

import "style";
import "width";

## Where a line sits in the width it is given.
export enum Alignment {
    ## Against the left edge.
    Left,
    ## In the middle; an odd leftover column goes to the right.
    Center,
    ## Against the right edge.
    Right,
}

## A run of text in one style.
export struct Span {
    ## The text; a line break in it is drawn as nothing.
    var content: String;
    ## The style laid over the line's.
    var style: Style;

    ## Makes an unstyled span, also from a `String` where a `Span` is
    ## expected.
    ##
    ## @param content the text
    [Implicit]
    construct(content: String) {
        this.content = content;
    }

    ## Makes a span.
    ##
    ## @param content the text
    ## @param style its style
    construct(content: String, style: Style) {
        this.content = content;
        this.style = style;
    }

    ## Returns the number of columns the span takes.
    ##
    ## @returns the display width
    width(): int {
        return display_width(content);
    }
}

## A row of spans, with a style beneath them all and an alignment.
export struct Line {
    ## The spans, left to right.
    var spans: Span[];
    ## The style beneath the spans' own.
    var style: Style;
    ## Where the line sits, when it is narrower than its area; Empty to
    ## follow the widget's.
    var alignment: Alignment?;

    ## Makes an unstyled line of one span, also from a `String` where a
    ## `Line` is expected.
    ##
    ## @param content the text
    [Implicit]
    construct(content: String) {
        spans = [Span(content)];
    }

    ## Makes a line.
    ##
    ## @param spans the spans, left to right
    ## @param style the style beneath them
    construct(spans: Span[], style: Style = Style()) {
        this.spans = spans;
        this.style = style;
    }

    ## Returns the number of columns the line takes.
    ##
    ## @returns the display width
    width(): int {
        var total = 0;
        for (var span in spans) {
            total += span.width();
        }
        return total;
    }

    ## Returns this line, aligned to `alignment`.
    ##
    ## @param alignment where it sits
    ## @returns this line
    aligned(alignment: Alignment): Line {
        this.alignment = Optional<Alignment>.Value(alignment);
        return this;
    }
}

## Lines stacked top to bottom, with a style beneath them all.
export struct Text {
    ## The lines, top to bottom.
    var lines: Line[];
    ## The style beneath the lines' own.
    var style: Style;

    ## Makes unstyled text, a line for each "\n"-separated part of
    ## `content`, also from a `String` where a `Text` is expected.
    ##
    ## @param content the text
    [Implicit]
    construct(content: String) {
        lines = Array<Line>();
        for (var part in content.split("\n")) {
            lines.append(Line(part));
        }
    }

    ## Makes text.
    ##
    ## @param lines the lines, top to bottom
    ## @param style the style beneath them
    construct(lines: Line[], style: Style = Style()) {
        this.lines = lines;
        this.style = style;
    }

    ## Returns the number of lines.
    ##
    ## @returns the height in rows
    height(): int {
        return lines.count as int;
    }

    ## Returns the width of the widest line.
    ##
    ## @returns the width in columns
    width(): int {
        var widest = 0;
        for (var line in lines) {
            widest = widest.max(line.width());
        }
        return widest;
    }

    ## Returns the text without its styles: the lines' spans, the lines
    ## joined by "\n".
    ##
    ## @returns the plain text
    to_string(): String {
        var plain = StringBuilder();
        for (ulong index in 0..lines.count) {
            if (index > 0) {
                plain.append("\n");
            }
            for (var span in lines[index].spans) {
                plain.append(span.content);
            }
        }
        return plain.to_string();
    }
}

# The column offset that places `width` columns in `available` ones.
_align_offset(alignment: Alignment, width: int, available: int): int {
    var spare = (available - width).max(0);
    return match (alignment) {
        Left => 0,
        Center => spare / 2,
        Right => spare,
    };
}
