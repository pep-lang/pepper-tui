## `Paragraph`: text in an area, cut at its edge or wrapped at word
## boundaries, and scrolled.

import text;
import "block";
import "buffer";
import "geometry";
import "style";
import "text";
import "widget";
import "width";

## Text drawn in an area: each line on its own row, cut at the right edge
## or, with `wrap`, wrapped at spaces (a word wider than the area is broken
## across rows). Widths are display widths, so wide characters and emoji
## take two columns.
##
## @example
##     import tui;
##     import [Block, Paragraph] from tui;
##
##     var help = Paragraph("Arrows move, q quits.", block = Block(title = "Help"), wrap = true);
export struct Paragraph {
    ## The text.
    var text: Text;
    ## The block around the text; borderless by default.
    var block: Block;
    ## The style of the whole area.
    var style: Style;
    ## Whether to wrap lines wider than the area, rather than cut them.
    var wrap: bool;
    ## Whether wrapping drops the spaces that would start a row.
    var trim: bool;
    ## The rows to skip from the top: the scroll position.
    var scroll: int;
    ## Where lines sit that do not choose for themselves.
    var alignment: Alignment;

    ## Makes a paragraph.
    ##
    ## @param text the text
    ## @param block the block around it
    ## @param style the style of the whole area
    ## @param wrap whether to wrap long lines
    ## @param trim whether wrapping drops the spaces that would start a row
    ## @param scroll the rows to skip from the top
    ## @param alignment where lines sit
    construct(
        text: Text,
        block: Block = Block(borders = BORDER_NONE),
        style: Style = Style(),
        wrap: bool = false,
        trim: bool = true,
        scroll: int = 0,
        alignment: Alignment = Alignment.Left
    ) {
        this.text = text;
        this.block = block;
        this.style = style;
        this.wrap = wrap;
        this.trim = trim;
        this.scroll = scroll;
        this.alignment = alignment;
    }

    ## Returns the number of rows the text takes at `width` columns, with
    ## this paragraph's wrapping: for a scrollbar's content length.
    ##
    ## @param width the width of the area inside the block
    ## @returns the number of rows
    line_count(width: int): int {
        return _rows(width).count as int;
    }

    # Each row to draw, with where it sits.
    _rows(width: int): _Row[] {
        var rows = Array<_Row>();
        for (var line in text.lines) {
            var line_alignment = line.alignment.value_or(alignment);
            var pieces = _graphemes(line, text.style);
            if (wrap) {
                for (var row in _wrap(pieces, width, trim)) {
                    rows.append(_Row(row, line_alignment));
                }
            } else {
                rows.append(_Row(pieces, line_alignment));
            }
        }
        return rows;
    }
}

extend Paragraph with Widget {
    render(area: Rect, buffer: Buffer) {
        buffer.set_style(area, style);
        block.render(area, buffer);
        var inner = block.inner(area);
        if (inner.is_empty()) {
            return;
        }
        var rows = _rows(inner.width);
        var y = inner.y;
        var index = scroll.max(0) as ulong;
        while (index < rows.count && y < inner.bottom) {
            var row = rows[index];
            var offset = _align_offset(row.alignment, _width_of(row.pieces), inner.width);
            _draw_pieces(buffer, inner.x + offset, y, row.pieces, inner.right);
            index += 1;
            y += 1;
        }
    }
}

# One character to draw, with any zero-width ones after it, its style and
# its width.
[Value]
struct _Grapheme {
    var symbol: String;
    var style: Style;
    var width: int;

    construct(symbol: String, style: Style, width: int) {
        this.symbol = symbol;
        this.style = style;
        this.width = width;
    }
}

struct _Row {
    var pieces: _Grapheme[];
    var alignment: Alignment;

    construct(pieces: _Grapheme[], alignment: Alignment) {
        this.pieces = pieces;
        this.alignment = alignment;
    }
}

# The characters of `line`, each with its span's style laid over the line's
# and `base`; control characters are dropped.
_graphemes(line: Line, base: Style): _Grapheme[] {
    var pieces = Array<_Grapheme>();
    var line_style = base.patch(line.style);
    for (var span in line.spans) {
        var span_style = line_style.patch(span.style);
        ulong offset = 0;
        var content = span.content;
        while (offset < content.size) {
            var (point, run) = text.Utf8.code_point_at(content, offset);
            var symbol = content.substr_bytes(offset, run);
            offset += run;
            var width = char_width(point);
            if (width > 0) {
                pieces.append(_Grapheme(symbol, span_style, width));
            } else if (point >= 768 && pieces.count > 0) {
                var last = pieces.pop();
                last.symbol += symbol;
                pieces.append(last);
            }
        }
    }
    return pieces;
}

_width_of(pieces: _Grapheme[]): int {
    var total = 0;
    for (var piece in pieces) {
        total += piece.width;
    }
    return total;
}

_draw_pieces(buffer: Buffer, x: int, y: int, pieces: _Grapheme[], right: int) {
    var column = x;
    for (var piece in pieces) {
        if (column + piece.width > right) {
            break;
        }
        column = buffer.set_string(column, y, piece.symbol, piece.style);
    }
}

# Breaks `pieces` into rows of at most `width` columns at spaces; a word
# wider than a row is broken where it reaches the edge. With `trim`, the
# spaces that would start a row are dropped.
_wrap(pieces: _Grapheme[], width: int, trim: bool): _Grapheme[][] {
    var rows = Array<_Grapheme[]>();
    if (width <= 0) {
        return rows;
    }
    var row = Array<_Grapheme>();
    var row_width = 0;
    var spaces = Array<_Grapheme>();
    var spaces_width = 0;
    ulong index = 0;
    while (index < pieces.count) {
        if (pieces[index].symbol == " ") {
            if (!(trim && row.count == 0)) {
                spaces.append(pieces[index]);
                spaces_width += pieces[index].width;
            }
            index += 1;
            continue;
        }
        var word = Array<_Grapheme>();
        var word_width = 0;
        while (index < pieces.count && pieces[index].symbol != " ") {
            word.append(pieces[index]);
            word_width += pieces[index].width;
            index += 1;
        }
        if (row_width + spaces_width + word_width > width && row.count > 0) {
            rows.append(row);
            row = Array<_Grapheme>();
            row_width = 0;
            spaces = Array<_Grapheme>();
            spaces_width = 0;
        }
        if (!(trim && row.count == 0)) {
            for (var space in spaces) {
                if (row_width + space.width <= width) {
                    row.append(space);
                    row_width += space.width;
                }
            }
        }
        spaces = Array<_Grapheme>();
        spaces_width = 0;
        for (var piece in word) {
            if (piece.width > width) {
                continue;  # never fits: a wide character in one column
            }
            if (row_width + piece.width > width) {
                rows.append(row);
                row = Array<_Grapheme>();
                row_width = 0;
            }
            row.append(piece);
            row_width += piece.width;
        }
    }
    for (var space in spaces) {
        if (row_width + space.width <= width) {
            row.append(space);
            row_width += space.width;
        }
    }
    rows.append(row);
    return rows;
}
