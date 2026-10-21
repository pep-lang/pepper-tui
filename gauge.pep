## `Gauge`: a bar filled to a ratio, with a label.

import "block";
import "buffer";
import "geometry";
import "style";
import "widget";
import "width";

# Partial blocks, one to seven eighths of a cell wide.
const _EIGHTHS = " ▏▎▍▌▋▊▉";

## A bar filled from the left to `ratio` of its width, with a label (the
## percentage by default) in the middle row. The label shows reversed where
## the bar is filled, so it stays readable.
##
## @example
##     import tui;
##     import [Gauge, Style] from tui;
##
##     var progress = Gauge(0.42);   # filled to 42%, labeled "42%"
export struct Gauge {
    ## How full the bar is, from 0 to 1; values outside are clamped.
    var ratio: double;
    ## The label; "" for the percentage.
    var label: String;
    ## The block around the gauge; borderless by default.
    var block: Block;
    ## The style of the whole area.
    var style: Style;
    ## The style of the filled part.
    var gauge_style: Style;
    ## Whether to fill the last cell by eighths, with Unicode's partial
    ## blocks, rather than by whole cells.
    var use_unicode: bool;

    ## Makes a gauge.
    ##
    ## @param ratio how full it is, from 0 to 1
    ## @param label the label; "" for the percentage
    ## @param block the block around the gauge
    ## @param style the style of the whole area
    ## @param gauge_style the style of the filled part
    ## @param use_unicode whether to fill by eighths of a cell
    construct(
        ratio: double,
        label: String = "",
        block: Block = Block(borders = BORDER_NONE),
        style: Style = Style(),
        gauge_style: Style = Style(),
        use_unicode: bool = false
    ) {
        this.ratio = ratio;
        this.label = label;
        this.block = block;
        this.style = style;
        this.gauge_style = gauge_style;
        this.use_unicode = use_unicode;
    }
}

extend Gauge with Widget {
    render(area: Rect, buffer: Buffer) {
        buffer.set_style(area, style);
        block.render(area, buffer);
        var inner = block.inner(area);
        if (inner.is_empty()) {
            return;
        }
        var clamped = ratio < 0.0 ? 0.0 : (ratio > 1.0 ? 1.0 : ratio);
        var eighths = (clamped * (inner.width as double) * 8.0) as int;
        var full = eighths / 8;
        var text = label.is_empty ? $"{(clamped * 100.0) as int}%" : label;
        var text_width = display_width(text);
        var text_x = inner.x + (inner.width - text_width).max(0) / 2;
        var text_y = inner.y + inner.height / 2;
        for (var y in inner.y..inner.bottom) {
            for (var x in inner.x..inner.right) {
                var filled = x - inner.x < full;
                if (filled) {
                    buffer.set_string(x, y, "█", gauge_style);
                } else if (use_unicode && x - inner.x == full && eighths % 8 > 0) {
                    buffer.set_string(x, y, _EIGHTHS.substr((eighths % 8) as ulong, 1), gauge_style);
                }
            }
        }
        var end = buffer.set_string(text_x, text_y, text, Style(), inner.right - text_x);
        var filled_end = (inner.x + full).min(end);
        if (filled_end > text_x) {
            buffer.set_style(Rect(text_x, text_y, filled_end - text_x, 1), gauge_style.add_modifier(REVERSE));
        }
    }
}
