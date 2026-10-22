## `Tabs`: a row of titles with one selected.

import term;
import "block";
import "buffer";
import "events";
import "geometry";
import "style";
import "text";
import "widget";
import "width";

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

    ## Selects the title a left click landed on, its padding included, with
    ## the tabs drawn in `area`. Keep the `Tabs` from frame to frame, or its
    ## `selected` in the app, to keep the choice.
    ##
    ## @param event the mouse event, as `Event.Mouse` gives it
    ## @param area where the tabs are drawn, such as `Terminal.area_of` gives
    ## @returns true when the click selected a title
    handle_mouse(event: term.MouseEvent, area: Rect): bool {
        var column = event.column as int;
        var inner = block.inner(area);
        if (!_is_left_click(event) || !inner.contains(column, event.row as int)) {
            return false;
        }
        # The same steps as `render`, measuring instead of drawing.
        var x = inner.x;
        for (ulong index in 0..titles.count) {
            if (index > 0) {
                x += display_width(divider);
            }
            var start = x;
            x += display_width(padding_left) + titles[index].width() + display_width(padding_right);
            if (column >= start && column < x) {
                selected = index;
                return true;
            }
        }
        return false;
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
