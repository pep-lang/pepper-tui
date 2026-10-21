## `Tabs`: a row of titles with one selected.

import "block";
import "buffer";
import "geometry";
import "style";
import "text";
import "widget";

## A row of titles, padded and separated by `divider`, with the selected
## one highlighted.
##
## @example
##     import tui;
##     import [Tabs] from tui;
##
##     var tabs = Tabs(["Files", "Search", "Help"], selected = 1);
##     # " Files │ Search │ Help "
export struct Tabs {
    ## The titles, left to right.
    var titles: Line[];
    ## The selected title.
    var selected: ulong;
    ## The block around the tabs; borderless by default.
    var block: Block;
    ## The style of the whole area.
    var style: Style;
    ## The style laid over the selected title.
    var highlight_style: Style;
    ## Drawn between titles.
    var divider: String;
    ## Drawn before each title.
    var padding_left: String;
    ## Drawn after each title.
    var padding_right: String;

    ## Makes tabs.
    ##
    ## @param titles the titles, left to right
    ## @param selected the selected title
    ## @param block the block around the tabs
    ## @param style the style of the whole area
    ## @param highlight_style the style of the selected title
    ## @param divider drawn between titles
    ## @param padding_left drawn before each title
    ## @param padding_right drawn after each title
    construct(
        titles: Line[],
        selected: ulong = 0,
        block: Block = Block(borders = BORDER_NONE),
        style: Style = Style(),
        highlight_style: Style = Style(reverse = true),
        divider: String = "│",
        padding_left: String = " ",
        padding_right: String = " "
    ) {
        this.titles = titles;
        this.selected = selected;
        this.block = block;
        this.style = style;
        this.highlight_style = highlight_style;
        this.divider = divider;
        this.padding_left = padding_left;
        this.padding_right = padding_right;
    }
}

extend Tabs with Widget {
    render(area: Rect, buffer: Buffer) {
        buffer.set_style(area, style);
        block.render(area, buffer);
        var inner = block.inner(area);
        if (inner.is_empty()) {
            return;
        }
        var x = inner.x;
        var right = inner.right;
        for (ulong index in 0..titles.count) {
            if (index > 0) {
                x = buffer.set_string(x, inner.y, divider, Style(), right - x);
            }
            x = buffer.set_string(x, inner.y, padding_left, Style(), right - x);
            var start = x;
            x = buffer.set_line(x, inner.y, titles[index], right - x);
            if (index == selected) {
                buffer.set_style(Rect(start, inner.y, x - start, 1), highlight_style);
            }
            x = buffer.set_string(x, inner.y, padding_right, Style(), right - x);
            if (x >= right) {
                break;
            }
        }
    }
}
