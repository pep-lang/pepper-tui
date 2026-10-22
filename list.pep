## `List`: items one under another, one of them selected, scrolled to keep
## the selection in view; `ListState` holds the selection and the scroll.

import term;
import "block";
import "buffer";
import "events";
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
    # What the last draw put where, for `handle_mouse`: the whole area, the
    # rows of items, the item on each of those rows, the item count, and a
    # table's header cells.
    var _area: Rect;
    var _rows: Rect;
    var _row_items = Array<ulong>();
    var _count: ulong;
    var _header = Array<Rect>();
    var _selected_text = "";

    ## Makes a state with nothing selected and no scroll.
    construct() {}

    ## Returns the text of the selected item, as the last draw with this
    ## state found it, without styles, for copying to the clipboard: a
    ## `List` item's lines joined by "\n", or a `Table` row's cells joined
    ## by a tab.
    ##
    ## @returns the text, or "" when nothing was selected at the last draw
    ## @example
    ##     import tui;
    ##
    ##     var state = tui.ListState();
    ##     state.select_next();
    ##     # after a frame draws a List with this state:
    ##     var copied = state.selected_text();   # the first item's text
    selected_text(): String {
        return _selected_text;
    }

    ## Acts on a mouse event as the `List` or `Table` last drawn with this
    ## state places it: a left click on an item selects it, a partly shown
    ## last item included, and the wheel over the widget moves the
    ## selection. Clicks on the borders and a table's header select
    ## nothing (see `header_clicked`).
    ##
    ## @param event the mouse event, as `Event.Mouse` gives it
    ## @returns true when it acted on the event
    ## @example
    ##     import tui;
    ##     import [Event] from tui;
    ##
    ##     var state = tui.ListState();
    ##     # in the event loop: if (event is Mouse(mouse)) { state.handle_mouse(mouse); }
    handle_mouse(event: term.MouseEvent): bool {
        var column = event.column as int;
        var row = event.row as int;
        if (_count == 0 || !_area.contains(column, row)) {
            return false;
        }
        if (event.kind == term.MouseKind.ScrollDown) {
            select(Optional<ulong>.Value(selected ? (selected.value() + 1).min(_count - 1) : 0));
            return true;
        }
        if (event.kind == term.MouseKind.ScrollUp) {
            select_previous();
            return true;
        }
        if (!_is_left_click(event) || !_rows.contains(column, row)) {
            return false;
        }
        var index = (row - _rows.y) as ulong;
        if (index >= _row_items.count) {
            return false;
        }
        select(Optional<ulong>.Value(_row_items[index]));
        return true;
    }

    ## Returns which column of a `Table`'s header a left click landed on,
    ## as the table last drawn with this state places it. The table does
    ## nothing with header clicks itself; an app may sort by the column.
    ##
    ## @param event the mouse event, as `Event.Mouse` gives it
    ## @returns the column, from 0, or Empty when the event is not a left
    ##   click on a header cell
    header_clicked(event: term.MouseEvent): ulong? {
        if (_is_left_click(event)) {
            for (ulong index in 0.._header.count) {
                if (_header[index].contains(event.column as int, event.row as int)) {
                    return Optional<ulong>.Value(index);
                }
            }
        }
        return Optional<ulong>.Empty;
    }

    # Starts a draw's record of where things are.
    _drawn(area: Rect, count: ulong) {
        _area = area;
        _rows = Rect();
        _row_items = Array<ulong>();
        _count = count;
        _header = Array<Rect>();
        _selected_text = "";
    }

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
        state._drawn(area, items.count);
        var inner = block.inner(area);
        if (inner.is_empty()) {
            return;
        }
        if (items.count == 0) {
            state.select(Optional<ulong>.Empty);
            return;
        }
        state._rows = inner;
        var heights = Array<int>();
        for (var item in items) {
            heights.append(item.height().max(1));
        }
        _clamp_selection(state, items.count);
        if (state.selected) {
            state._selected_text = items[state.selected.value()].to_string();
        }
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
            for (var _ in 0..rows) {
                state._row_items.append(index);
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
