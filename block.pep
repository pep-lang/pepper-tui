## `Block`: a border with a title around another widget, and the area
## inside it.

import "buffer";
import "geometry";
import "style";
import "text";
import "widget";

## No border, for `Block.borders`.
export const BORDER_NONE = 0;
## The top border.
export const BORDER_TOP = 1;
## The right border.
export const BORDER_RIGHT = 2;
## The bottom border.
export const BORDER_BOTTOM = 4;
## The left border.
export const BORDER_LEFT = 8;
## All four borders.
export const BORDER_ALL = 15;

## The lines a border is drawn with.
export enum BorderType {
    ## Thin lines with square corners: ┌─┐.
    Plain,
    ## Thin lines with round corners: ╭─╮.
    Rounded,
    ## Double lines: ╔═╗.
    Double,
    ## Thick lines: ┏━┓.
    Thick,
}

## A border with a title, drawn around an area; other widgets take one to
## draw themselves inside it.
##
## @example
##     import tui;
##     import [Block, BorderType] from tui;
##
##     var block = Block(title = "Files", border_type = BorderType.Rounded);
##     # ╭Files───╮
##     # │        │
##     # ╰────────╯
export struct Block {
    ## The title, drawn on the top border; an empty line for none.
    var title: Line;
    ## Where the title sits on the top border.
    var title_alignment: Alignment;
    ## Which borders to draw: `BORDER_TOP`, `BORDER_RIGHT`,
    ## `BORDER_BOTTOM` and `BORDER_LEFT` or-ed together, or `BORDER_ALL`.
    var borders: int;
    ## The lines the borders are drawn with.
    var border_type: BorderType;
    ## The style of the borders, laid over `style`.
    var border_style: Style;
    ## The style of the whole area, borders and inside.
    var style: Style;
    ## Cells left empty inside the borders, on every side.
    var padding: int;

    ## Makes a block.
    ##
    ## @param title the title; "" for none
    ## @param borders which borders to draw
    ## @param border_type the lines to draw them with
    ## @param title_alignment where the title sits
    ## @param style the style of the whole area
    ## @param border_style the style of the borders
    ## @param padding cells left empty inside the borders
    construct(
        title: Line = "",
        borders: int = BORDER_ALL,
        border_type: BorderType = BorderType.Plain,
        title_alignment: Alignment = Alignment.Left,
        style: Style = Style(),
        border_style: Style = Style(),
        padding: int = 0
    ) {
        this.title = title;
        this.borders = borders;
        this.border_type = border_type;
        this.title_alignment = title_alignment;
        this.style = style;
        this.border_style = border_style;
        this.padding = padding;
    }

    ## Returns the area inside the borders and the padding.
    ##
    ## @param area the block's area
    ## @returns the inner area, empty when nothing fits
    inner(area: Rect): Rect {
        var left = (borders & BORDER_LEFT) != 0 ? 1 : 0;
        var right = (borders & BORDER_RIGHT) != 0 ? 1 : 0;
        var top = (borders & BORDER_TOP) != 0 || title.width() > 0 ? 1 : 0;
        var bottom = (borders & BORDER_BOTTOM) != 0 ? 1 : 0;
        var inside = Rect(area.x + left, area.y + top, area.width - left - right, area.height - top - bottom);
        return inside.inner(padding, padding);
    }

    # The horizontal line, vertical line and the corners: top left, top
    # right, bottom left, bottom right.
    _symbols(): String[] {
        return match (border_type) {
            Plain => ["─", "│", "┌", "┐", "└", "┘"],
            Rounded => ["─", "│", "╭", "╮", "╰", "╯"],
            Double => ["═", "║", "╔", "╗", "╚", "╝"],
            Thick => ["━", "┃", "┏", "┓", "┗", "┛"],
        };
    }
}

extend Block with Widget {
    render(area: Rect, buffer: Buffer) {
        var target = area.intersection(buffer.area);
        if (target.is_empty()) {
            return;
        }
        buffer.set_style(target, style);
        var lines = _symbols();
        var edge = style.patch(border_style);
        var left = target.x;
        var right = target.right - 1;
        var top = target.y;
        var bottom = target.bottom - 1;
        if ((borders & BORDER_TOP) != 0) {
            for (var x in left..>right) {
                buffer.set_string(x, top, lines[0], edge);
            }
        }
        if ((borders & BORDER_BOTTOM) != 0) {
            for (var x in left..>right) {
                buffer.set_string(x, bottom, lines[0], edge);
            }
        }
        if ((borders & BORDER_LEFT) != 0) {
            for (var y in top..>bottom) {
                buffer.set_string(left, y, lines[1], edge);
            }
        }
        if ((borders & BORDER_RIGHT) != 0) {
            for (var y in top..>bottom) {
                buffer.set_string(right, y, lines[1], edge);
            }
        }
        _corner(buffer, BORDER_TOP | BORDER_LEFT, left, top, lines[2], edge);
        _corner(buffer, BORDER_TOP | BORDER_RIGHT, right, top, lines[3], edge);
        _corner(buffer, BORDER_BOTTOM | BORDER_LEFT, left, bottom, lines[4], edge);
        _corner(buffer, BORDER_BOTTOM | BORDER_RIGHT, right, bottom, lines[5], edge);
        var title_width = title.width();
        if (title_width > 0) {
            var start = left + ((borders & BORDER_LEFT) != 0 ? 1 : 0);
            var room = right + 1 - ((borders & BORDER_RIGHT) != 0 ? 1 : 0) - start;
            var offset = _align_offset(title.alignment.value_or(title_alignment), title_width, room);
            buffer.set_line(start + offset, top, title, room - offset);
        }
    }

    _corner(buffer: Buffer, sides: int, x: int, y: int, symbol: String, edge: Style) {
        if ((borders & sides) == sides) {
            buffer.set_string(x, y, symbol, edge);
        }
    }
}
