## `Sparkline`: a row of tiny bars, one column per value.

import "block";
import "buffer";
import "geometry";
import "style";
import "widget";

# The bar symbols for zero to eight eighths of a cell.
const _BARS = " ▁▂▃▄▅▆▇█";

## One column per value, from the left, each a bar as tall as its value
## against `max`, drawn in eighths of a cell. Values past the area's width
## are not drawn.
##
## @example
##     import tui;
##     import [Sparkline] from tui;
##
##     var load = Sparkline([1, 4, 8, 2]);   # "▁▄█▂" in one row
export struct Sparkline {
    ## The values, left to right.
    var data: ulong[];
    ## The value of a full-height bar; 0 for the largest value.
    var max: ulong;
    ## The block around the sparkline; borderless by default.
    var block: Block;
    ## The style of the bars.
    var style: Style;

    ## Makes a sparkline.
    ##
    ## @param data the values, left to right
    ## @param max the value of a full-height bar; 0 for the largest value
    ## @param block the block around it
    ## @param style the style of the bars
    construct(data: ulong[], max: ulong = 0, block: Block = Block(borders = BORDER_NONE), style: Style = Style()) {
        this.data = data;
        this.max = max;
        this.block = block;
        this.style = style;
    }
}

extend Sparkline with Widget {
    render(area: Rect, buffer: Buffer) {
        buffer.set_style(area, style);
        block.render(area, buffer);
        var inner = block.inner(area);
        if (inner.is_empty()) {
            return;
        }
        var top = max;
        if (top == 0) {
            for (var value in data) {
                top = top.max(value);
            }
        }
        var count = data.count.min(inner.width as ulong);
        for (ulong index in 0..count) {
            var eighths = _eighths(data[index], top, inner.height);
            _draw_bar(buffer, inner.x + index as int, inner.bottom - 1, eighths, inner.height, style);
        }
    }
}

# How many eighths of a cell tall `value` is, against `top` in `rows`.
_eighths(value: ulong, top: ulong, rows: int): int {
    if (top == 0) {
        return 0;
    }
    return (value.min(top) * (rows as ulong) * 8 / top) as int;
}

# Draws a bar `eighths` tall upward from row `bottom` at column `x`, at most
# `rows` rows.
_draw_bar(buffer: Buffer, x: int, bottom: int, eighths: int, rows: int, style: Style) {
    for (var row in 0..rows) {
        var left = (eighths - row * 8).max(0).min(8);
        if (left > 0) {
            buffer.set_string(x, bottom - row, _BARS.substr(left as ulong, 1), style);
        }
    }
}
