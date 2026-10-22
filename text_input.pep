## `TextInput`: an editable field of text, on one row or wrapped over
## many, with a cursor, a selection and pastes; `TextInputState` holds the
## text and the cursor from frame to frame.

import term;
import text;
import "block";
import "buffer";
import "events";
import "geometry";
import "style";
import "widget";
import "width";

## The state of a `TextInput`: the text, the cursor, the selection and the
## scroll. Feed it the app's events with `handle_event`; drawing scrolls it
## to keep the cursor in view.
##
## The cursor and the selection move a character at a time: a code point
## with the combining marks after it. Widths are display widths, so a wide
## character takes two columns.
##
## @example
##     import tui;
##
##     var state = tui.TextInputState();
##     state.set_text("hello");
##     state.paste("\nworld");   # one row: the line end becomes a space
##     assert(state.text == "hello world", "pasted at the cursor");
export struct TextInputState {
    ## Whether the field takes line ends, from Enter and pastes, and wraps
    ## its text over the rows of its area; otherwise it is one row that
    ## scrolls sideways.
    var multiline: bool;
    ## For a one-row field, whether a paste keeps its line ends, each shown
    ## as "⏎", rather than turning each into a space.
    var keep_newlines: bool;
    ## Whether the last paste was cut short: pepper-term keeps only the
    ## start of a paste past its limit (a megabyte).
    var paste_truncated: bool;
    ## The first column (one row) or the first row (multiline) shown.
    var scroll: int;
    var _text = "";
    # The cursor and the selection's other end, as byte offsets.
    var _cursor: ulong;
    var _anchor: ulong?;
    # The width the last draw wrapped at, for Up and Down; 0 before one.
    var _width: int;

    ## Makes an empty field.
    ##
    ## @param multiline whether it takes line ends and wraps
    ## @param keep_newlines for one row, whether pastes keep line ends
    construct(multiline: bool = false, keep_newlines: bool = false) {
        this.multiline = multiline;
        this.keep_newlines = keep_newlines;
    }

    ## The text.
    var text: String {
        get {
            return _text;
        }
    }

    ## The cursor, as a byte offset into `text`.
    var cursor: ulong {
        get {
            return _cursor;
        }
    }

    ## Replaces the text, putting the cursor at its end and selecting
    ## nothing.
    ##
    ## @param value the new text
    set_text(value: String) {
        _text = value;
        _cursor = value.size;
        _anchor = Optional<ulong>.Empty;
    }

    ## Selects the whole text, with the cursor at its end.
    select_all() {
        _anchor = Optional<ulong>.Value(0);
        _cursor = _text.size;
    }

    ## Returns the selected text, for copying to the clipboard.
    ##
    ## @returns the text between the selection's ends, or "" when nothing
    ##   is selected
    ## @example
    ##     import tui;
    ##
    ##     var state = tui.TextInputState();
    ##     state.set_text("hello");
    ##     state.select_all();
    ##     assert(state.selected_text() == "hello", "all of it");
    selected_text(): String {
        var (start, end) = _selection();
        return _text.substr_bytes(start, end - start);
    }

    ## Puts `value` in at the cursor, in place of the selection, and moves
    ## the cursor past it. Line ends go in as they are, even in a one-row
    ## field (which shows each as "⏎"); `paste` turns them into spaces
    ## there.
    ##
    ## @param value the text to put in
    insert(value: String) {
        var (start, end) = _selection();
        _text = _text.substr_bytes(0, start) + value + _text.substr_bytes(end, _text.size - end);
        _cursor = start + value.size;
        _anchor = Optional<ulong>.Empty;
    }

    ## Puts a paste in at the cursor, as `Event.Paste` gives it: in a
    ## one-row field without `keep_newlines`, each line end becomes a
    ## space. Sets `paste_truncated` to `truncated`.
    ##
    ## @param value the pasted text, with "\n" line ends
    ## @param truncated whether the paste was cut short
    paste(value: String, truncated: bool = false) {
        insert(multiline || keep_newlines ? value : value.replace("\n", " "));
        paste_truncated = truncated;
    }

    ## Acts on an event: a key (see `handle_key`) or a paste.
    ##
    ## @param event the event, as `Events.next` gives it
    ## @returns true when it acted on the event; the app handles the rest
    handle_event(event: Event): bool {
        match (event) {
            Key(key) => {
                return handle_key(key);
            }
            Paste(pasted, truncated) => {
                paste(pasted, truncated);
                return true;
            }
            else => {
                return false;
            }
        }
    }

    ## Acts on a key as a text field does: a character goes in at the
    ## cursor; Backspace and Delete remove the selection or the character
    ## before or after the cursor; Left, Right, Home and End move the
    ## cursor (to the start or end of its line), selecting with Shift held;
    ## in a multiline field Enter puts in a line end, and Up and Down move
    ## a row as the last draw wrapped it.
    ##
    ## Keys with Ctrl or Alt, Tab, Escape, and Enter in a one-row field are
    ## left to the app.
    ##
    ## @param key the key, as `Event.Key` gives it
    ## @returns true when it acted on the key
    handle_key(key: term.KeyEvent): bool {
        if (key.ctrl || key.alt) {
            return false;
        }
        var starts = _starts(_text);
        match (key.key) {
            Char => {
                insert(key.text);
            }
            Enter => {
                if (!multiline) {
                    return false;
                }
                insert("\n");
            }
            Backspace => {
                if (_has_selection()) {
                    insert("");
                } else if (_cursor > 0) {
                    _anchor = Optional<ulong>.Value(_before(starts, _cursor));
                    insert("");
                }
            }
            Delete => {
                if (_has_selection()) {
                    insert("");
                } else if (_cursor < _text.size) {
                    _anchor = Optional<ulong>.Value(_after(starts, _cursor, _text.size));
                    insert("");
                }
            }
            Left => {
                _move(_before(starts, _cursor), key.shift);
            }
            Right => {
                _move(_after(starts, _cursor, _text.size), key.shift);
            }
            Home => {
                var line = _text.substr_bytes(0, _cursor).rfind("\n");
                _move(line < 0 ? 0 : (line + 1) as ulong, key.shift);
            }
            End => {
                var line = _text.find("\n", _cursor);
                _move(line < 0 ? _text.size : line as ulong, key.shift);
            }
            Up => {
                return multiline && _move_row(-1, key.shift);
            }
            Down => {
                return multiline && _move_row(1, key.shift);
            }
            else => {
                return false;
            }
        }
        return true;
    }

    _has_selection(): bool {
        return _anchor && _anchor.value() != _cursor;
    }

    # The selection's start and end, both the cursor when there is none.
    _selection(): (ulong, ulong) {
        var anchor = _anchor.value_or(_cursor);
        return (anchor.min(_cursor), anchor.max(_cursor));
    }

    # Moves the cursor to `to`, keeping the selection's other end with
    # `select`, else selecting nothing.
    _move(to: ulong, select: bool) {
        if (select && _anchor.is_empty()) {
            _anchor = Optional<ulong>.Value(_cursor);
        } else if (!select) {
            _anchor = Optional<ulong>.Empty;
        }
        _cursor = to;
    }

    # Moves the cursor `step` rows up (-1) or down (1), to the character
    # nearest its column, as the last draw laid the text out.
    _move_row(step: int, select: bool): bool {
        var layout = _layout(_text, _width > 0 ? _width : 1000000, true);
        var at = layout.find(_cursor);
        var row = at.row + step;
        if (row < 0 || row > layout.end.row) {
            return false;
        }
        var to = Optional<ulong>.Empty;
        for (var placed in layout.placed) {
            if (placed.row == row && placed.column <= at.column) {
                to = Optional<ulong>.Value(placed.offset);
            }
        }
        if (row == layout.end.row && (to.is_empty() || layout.end.column <= at.column)) {
            to = Optional<ulong>.Value(_text.size);
        }
        if (to.is_empty()) {
            return false;
        }
        _move(to.value(), select);
        return true;
    }
}

## An editable field of text, drawn from a `TextInputState`: the text,
## the selection in `selection_style`, and the cursor as a cell in
## `cursor_style`. A one-row field scrolls sideways to keep the cursor in
## view; a multiline one wraps at the area's width, keeps its line ends,
## and scrolls down.
##
## Text that could move the cursor or send the terminal a sequence shows
## harmlessly: a line end in a one-row field as "⏎", and any other control
## character (C0, DEL and C1) as U+FFFD.
##
## @example
##     import tui;
##     import [Block, TextInput, TextInputState] from tui;
##
##     var input = TextInput(block = Block(title = "Name"));
##     var state = TextInputState();
##     # in the event loop: state.handle_event(event.value());
##     # in a frame: frame.render_stateful_widget(input, area, state);
export struct TextInput {
    ## The block around the field; borderless by default.
    var block: Block;
    ## The style of the whole area.
    var style: Style;
    ## The style laid over the selected text.
    var selection_style: Style;
    ## The style laid over the cell at the cursor; `Style()` hides the
    ## cursor, as for a field without focus.
    var cursor_style: Style;

    ## Makes a text field.
    ##
    ## @param block the block around it
    ## @param style the style of the whole area
    ## @param selection_style the style of the selected text
    ## @param cursor_style the style of the cell at the cursor
    construct(
        block: Block = Block(borders = BORDER_NONE),
        style: Style = Style(),
        selection_style: Style = Style(reverse = true),
        cursor_style: Style = Style(reverse = true)
    ) {
        this.block = block;
        this.style = style;
        this.selection_style = selection_style;
        this.cursor_style = cursor_style;
    }
}

extend TextInput with StatefulWidget<TextInputState> {
    render(area: Rect, buffer: Buffer, state: TextInputState) {
        buffer.set_style(area, style);
        block.render(area, buffer);
        var inner = block.inner(area);
        if (inner.is_empty()) {
            return;
        }
        state._width = inner.width;
        var multiline = state.multiline;
        var layout = _layout(state._text, inner.width, multiline);
        var at = layout.find(state._cursor);
        # Scroll so the cursor's cell shows, and no further than the text.
        if (multiline) {
            var last = (layout.end.row - inner.height + 1).max(0);
            state.scroll = state.scroll.min(last).min(at.row).max(at.row - inner.height + 1).max(0);
        } else {
            var last = (layout.end.column + 1 - inner.width).max(0);
            state.scroll = state.scroll.min(last).min(at.column).max(at.column + at.width - inner.width).max(0);
        }
        var dx = inner.x - (multiline ? 0 : state.scroll);
        var dy = inner.y - (multiline ? state.scroll : 0);
        var (start, end) = state._selection();
        for (var placed in layout.placed) {
            var x = placed.column + dx;
            var y = placed.row + dy;
            if (x >= inner.x && x + placed.width <= inner.right && y >= inner.y && y < inner.bottom) {
                var chosen = placed.offset >= start && placed.offset < end;
                buffer.set_string(x, y, placed.symbol, chosen ? selection_style : Style());
            }
        }
        var x = at.column + dx;
        var y = at.row + dy;
        if (x >= inner.x && x < inner.right && y >= inner.y && y < inner.bottom) {
            buffer.set_style(Rect(x, y, at.width.min(inner.right - x), 1), cursor_style);
        }
    }
}

# One character of the text as laid out: where it starts in the text, what
# shows for it, and the row, column and width it takes.
[Value]
struct _Placed {
    var offset: ulong;
    var symbol: String;
    var row: int;
    var column: int;
    var width: int;

    construct(offset: ulong, symbol: String, row: int, column: int, width: int) {
        this.offset = offset;
        this.symbol = symbol;
        this.row = row;
        this.column = column;
        this.width = width;
    }
}

struct _Layout {
    var placed = Array<_Placed>();
    # Where a cursor at the end of the text sits.
    var end = _Placed(0, " ", 0, 0, 1);

    construct() {}

    # Where a cursor at byte `offset` sits.
    find(offset: ulong): _Placed {
        for (var item in placed) {
            if (item.offset == offset) {
                return item;
            }
        }
        return end;
    }
}

# Lays `value` out at `width` columns: on one row, or, `multiline`, a row
# per line, each wrapped where its next character would pass `width`.
_layout(value: String, width: int, multiline: bool): _Layout {
    var layout = _Layout();
    var row = 0;
    var column = 0;
    var starts = _starts(value);
    for (ulong index in 0..starts.count) {
        var offset = starts[index];
        var next = index + 1 < starts.count ? starts[index + 1] : value.size;
        var piece = value.substr_bytes(offset, next - offset);
        if (multiline && piece == "\n") {
            # The cursor on a line end sits after the line's last character.
            layout.placed.append(_Placed(offset, " ", row, column, 1));
            row += 1;
            column = 0;
            continue;
        }
        var symbol = _shown(piece);
        var piece_width = display_width(symbol);
        if (piece_width == 0) {
            # A combining mark with nothing to join, or a zero-width character.
            symbol = "\u{FFFD}";
            piece_width = 1;
        }
        if (multiline && column > 0 && column + piece_width > width) {
            row += 1;
            column = 0;
        }
        layout.placed.append(_Placed(offset, symbol, row, column, piece_width));
        column += piece_width;
    }
    if (multiline && column >= width) {
        row += 1;
        column = 0;
    }
    layout.end = _Placed(value.size, " ", row, column, 1);
    return layout;
}

# The byte offset where each character of `value` starts: a code point
# with the combining marks after it.
_starts(value: String): ulong[] {
    var starts = Array<ulong>();
    ulong offset = 0;
    while (offset < value.size) {
        var (point, run) = text.Utf8.code_point_at(value, offset);
        if (!(point >= 768 && char_width(point) == 0 && starts.count > 0 && !_is_control(value.byte_at(offset - 1)))) {
            starts.append(offset);
        }
        offset += run;
    }
    return starts;
}

# The start of the character before `offset`.
_before(starts: ulong[], offset: ulong): ulong {
    ulong before = 0;
    for (var start in starts) {
        if (start >= offset) {
            break;
        }
        before = start;
    }
    return before;
}

# The start of the character after the one at `offset`, or `size`.
_after(starts: ulong[], offset: ulong, size: ulong): ulong {
    for (var start in starts) {
        if (start > offset) {
            return start;
        }
    }
    return size;
}

_is_control(byte: u8): bool {
    return byte < 32 || byte == 127;
}

# How the character `piece` shows: a line end as "⏎", another control
# character (C0, DEL, and C1, U+0080 to U+009F, which some terminals obey)
# as U+FFFD, so text cannot move the cursor or send the terminal sequences.
_shown(piece: String): String {
    var byte = piece.byte_at(0);
    if (byte == '\n') {
        return "⏎";
    }
    if (_is_control(byte) || (byte == 194 && piece.size > 1 && piece.byte_at(1) < 160)) {
        return "\u{FFFD}";
    }
    return piece;
}
