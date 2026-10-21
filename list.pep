## `List`: items one under another, one of them selected, scrolled to keep
## the selection in view; `ListState` holds the selection and the scroll.

import "block";
import "buffer";
import "geometry";
import "style";
import "text";
import "widget";
import "width";

## The state of a `List` or a `Table` from frame to frame: which item is
## selected and how far it is scrolled. Drawing moves `offset` so the
## selected item shows, and keeps `selected` below the item count.
##
## @example
##     import tui;
##
##     var state = tui.ListState();
##     state.select_next();   # selects item 0
##     state.select_next();   # item 1
export struct ListState {
    ## The selected item, or Empty for none.
    var selected: ulong?;
    ## The first item shown.
    var offset: ulong;

    ## Makes a state with nothing selected and no scroll.
    construct() {}

    ## Selects `index`, or nothing for Empty.
    ##
    ## @param index the item to select
    select(index: ulong?) {
        selected = index;
        if (index.is_empty()) {
            offset = 0;
        }
    }

    ## Selects the next item, or the first when none is; drawing keeps it
    ## at the last item.
    select_next() {
        selected = Optional<ulong>.Value(selected ? selected.value() + 1 : 0);
    }

    ## Selects the item before, staying at the first; the first when none
    ## is selected.
    select_previous() {
        var index = selected.value_or(0);
        selected = Optional<ulong>.Value(index > 0 ? index - 1 : 0);
    }
}

## The state of a `Table`: the selected row and the scroll.
export type TableState = ListState;

## Items one under another, each a `Text` (one or more rows), with the
## selected one highlighted and marked with `highlight_symbol`.
##
## As a `StatefulWidget<ListState>` it draws the selection and scrolls to
## it; as a `Widget` it draws the items from the top with none selected.
##
## @example
##     import tui;
##     import [Block, List, ListState, Style] from tui;
##
##     var list = List(["one", "two", "three"], block = Block(title = "Items"), highlight_symbol = "> ");
##     var state = ListState();
##     state.select_next();
##     # in a frame: frame.render_stateful_widget(list, area, state);
export struct List {
    ## The items, top to bottom.
    var items: Text[];
    ## The block around the list; borderless by default.
    var block: Block;
    ## The style of the whole area.
    var style: Style;
    ## The style laid over the selected item's rows.
    var highlight_style: Style;
    ## Drawn before the selected item; the other items are indented by its
    ## width while an item is selected.
    var highlight_symbol: String;

    ## Makes a list.
    ##
    ## @param items the items, top to bottom
    ## @param block the block around the list
    ## @param style the style of the whole area
    ## @param highlight_style the style of the selected item
    ## @param highlight_symbol the mark before the selected item
    construct(
        items: Text[],
        block: Block = Block(borders = BORDER_NONE),
        style: Style = Style(),
        highlight_style: Style = Style(reverse = true),
        highlight_symbol: String = ""
    ) {
        this.items = items;
        this.block = block;
        this.style = style;
        this.highlight_style = highlight_style;
        this.highlight_symbol = highlight_symbol;
    }
}

extend List with StatefulWidget<ListState> {
    render(area: Rect, buffer: Buffer, state: ListState) {
        buffer.set_style(area, style);
        block.render(area, buffer);
        var inner = block.inner(area);
        if (inner.is_empty()) {
            return;
        }
        if (items.count == 0) {
            state.select(Optional<ulong>.Empty);
            return;
        }
        var heights = Array<int>();
        for (var item in items) {
            heights.append(item.height().max(1));
        }
        _clamp_selection(state, items.count);
        state.offset = _visible_offset(heights, state, inner.height);
        var mark = state.selected ? display_width(highlight_symbol) : 0;
        var y = inner.y;
        var index = state.offset;
        while (index < items.count && y < inner.bottom) {
            var item = items[index];
            var chosen = state.selected && state.selected.value() == index;
            var rows = heights[index].min(inner.bottom - y);
            for (var row in 0..rows) {
                if (chosen && row == 0) {
                    buffer.set_string(inner.x, y + row, highlight_symbol, Style(), mark);
                }
                if (row < item.lines.count as int) {
                    var line = item.lines[row];
                    var room = inner.width - mark;
                    var offset = _align_offset(line.alignment.value_or(Alignment.Left), line.width(), room);
                    buffer.set_style(Rect(inner.x + mark, y + row, room, 1), item.style);
                    buffer.set_line(inner.x + mark + offset, y + row, line, room - offset);
                }
            }
            if (chosen) {
                buffer.set_style(Rect(inner.x, y, inner.width, rows), highlight_style);
            }
            y += rows;
            index += 1;
        }
    }
}

extend List with Widget {
    render(area: Rect, buffer: Buffer) {
        render(area, buffer, ListState());
    }
}

# Keeps the selection below `count`.
_clamp_selection(state: ListState, count: ulong) {
    if (state.selected && state.selected.value() >= count) {
        state.selected = Optional<ulong>.Value(count - 1);
    }
}

# The first item to show, from `state.offset`, so the selected item (rows
# `heights`) fits in `height` rows.
_visible_offset(heights: int[], state: ListState, height: int): ulong {
    var offset = state.offset.min(heights.count - 1);
    if (state.selected.is_empty()) {
        return offset;
    }
    var selected = state.selected.value();
    if (selected < offset) {
        return selected;
    }
    # Scroll down until the rows from `offset` through the selection fit.
    var used = 0;
    for (var index in offset..>selected) {
        used += heights[index];
    }
    while (used > height && offset < selected) {
        used -= heights[offset];
        offset += 1;
    }
    return offset;
}
