## `BarChart`: labeled vertical bars.

import "block";
import "buffer";
import "geometry";
import "sparkline";
import "style";
import "widget";
import "width";

## Vertical bars, one per `(label, value)` pair, from the left: each as tall
## as its value against `max`, drawn in eighths of a cell, with its value
## on its bottom row when it fits and its label under it.
##
## @example
##     import tui;
##     import [BarChart] from tui;
##
##     var chart = BarChart([("Mon", 3), ("Tue", 7)], bar_width = 3);
export struct BarChart {
    ## The bars: a label and a value each.
    var data: Array<(String, ulong)>;
    ## The columns each bar takes.
    var bar_width: int;
    ## The columns between bars.
    var bar_gap: int;
    ## The value of a full-height bar; 0 for the largest value.
    var max: ulong;
    ## The block around the chart; borderless by default.
    var block: Block;
    ## The style of the whole area.
    var style: Style;
    ## The style of the bars.
    var bar_style: Style;
    ## The style of the values, laid over the bar's.
    var value_style: Style;
    ## The style of the labels.
    var label_style: Style;

    ## Makes a bar chart.
    ##
    ## @param data the bars: a label and a value each
    ## @param bar_width the columns each bar takes
    ## @param bar_gap the columns between bars
    ## @param max the value of a full-height bar; 0 for the largest value
    ## @param block the block around the chart
    ## @param style the style of the whole area
    ## @param bar_style the style of the bars
    ## @param value_style the style of the values
    ## @param label_style the style of the labels
    construct(
        data: Array<(String, ulong)>,
        bar_width: int = 1,
        bar_gap: int = 1,
        max: ulong = 0,
        block: Block = Block(borders = BORDER_NONE),
        style: Style = Style(),
        bar_style: Style = Style(),
        value_style: Style = Style(reverse = true),
        label_style: Style = Style()
    ) {
        this.data = data;
        this.bar_width = bar_width;
        this.bar_gap = bar_gap;
        this.max = max;
        this.block = block;
        this.style = style;
        this.bar_style = bar_style;
        this.value_style = value_style;
        this.label_style = label_style;
    }
}

extend BarChart with Widget {
    render(area: Rect, buffer: Buffer) {
        buffer.set_style(area, style);
        block.render(area, buffer);
        var inner = block.inner(area);
        if (inner.is_empty() || bar_width <= 0) {
            return;
        }
        var labeled = false;
        var top = max;
        for (var (label, value) in data) {
            labeled = labeled || !label.is_empty;
            if (max == 0) {
                top = top.max(value);
            }
        }
        var label_rows = labeled ? 1 : 0;
        var rows = inner.height - label_rows;
        var x = inner.x;
        for (var (label, value) in data) {
            if (x + bar_width > inner.right) {
                break;
            }
            if (rows > 0) {
                var eighths = _eighths(value, top, rows);
                for (var column in x..(x + bar_width)) {
                    _draw_bar(buffer, column, inner.y + rows - 1, eighths, rows, bar_style);
                }
                var number = $"{value}";
                var number_width = display_width(number);
                if (value > 0 && number_width <= bar_width && eighths >= 8) {
                    var start = x + (bar_width - number_width) / 2;
                    buffer.set_string(start, inner.y + rows - 1, number, bar_style.patch(value_style));
                }
            }
            if (labeled) {
                var label_width = display_width(label).min(bar_width);
                buffer.set_string(x + (bar_width - label_width) / 2, inner.bottom - 1, label, label_style, bar_width);
            }
            x += bar_width + bar_gap.max(0);
        }
    }
}
