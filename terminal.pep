## Drawing a frame at a time: `Terminal` keeps the last frame's `Buffer`,
## has the app draw the next one into a `Frame`, and sends its backend only
## the cells that changed. `TermBackend` writes to the real terminal through
## pepper-term; `TestBackend` keeps the screen as a buffer, for tests.

import io;
import term;
import "buffer";
import "geometry";
import "restore";
import "style";
import "widget";
import "width";

## Where a `Terminal` sends its frames: a real terminal, or a buffer in a
## test.
export trait Backend {
    ## Returns the screen's size, at the top left.
    ##
    ## @returns the screen's area
    size(): Rect;

    ## Writes the cells in `updates` to the screen.
    ##
    ## @param updates the cells that changed, row by row
    draw(updates: CellUpdate[]);

    ## Erases the whole screen.
    clear();

    ## Hides the cursor.
    hide_cursor();

    ## Shows the cursor at column `x` and row `y`.
    ##
    ## @param x the column
    ## @param y the row
    show_cursor(x: int, y: int);

    ## Sends what was written to the screen.
    flush();
}

## The backend of a real terminal: it writes escape sequences to standard
## output through pepper-term, all of a frame's in one write, and holds raw
## mode (and, when asked, mouse reporting and bracketed paste) on while it
## lives. Make one with `init`.
export struct TermBackend {
    var _raw: term.RawMode;
    var _mouse: term.MouseMode?;
    var _paste: term.PasteMode?;
    var _out = io.File.stdout();
    var _pending = StringBuilder();

    ## Makes the backend, turning raw mode on while it lives. `init` makes
    ## one and sets up the screen too.
    ##
    ## @param mouse whether to turn mouse reporting on too: presses,
    ##   releases, drags and the wheel
    ## @param paste whether to turn bracketed paste on too, so a paste
    ##   arrives as one `Event.Paste`
    construct(mouse: bool = false, paste: bool = false) {
        _raw = term.RawMode();
        if (mouse) {
            _mouse = Optional<term.MouseMode>.Value(term.MouseMode(term.MouseTracking.Drag));
        }
        if (paste) {
            _paste = Optional<term.PasteMode>.Value(term.PasteMode());
        }
    }

    # Paste and mouse reporting go off before raw mode, the reverse of
    # turning on.
    destruct {
        if (_paste) {
            _paste.value().exit();
        }
        if (_mouse) {
            _mouse.value().exit();
        }
    }
}

extend TermBackend with Backend {
    size(): Rect {
        var size = term.size();
        if (size.is_empty()) {
            return Rect(0, 0, 80, 24);
        }
        return Rect(0, 0, size.value().columns as int, size.value().rows as int);
    }

    draw(updates: CellUpdate[]) {
        var x = -1;
        var y = -1;
        var style = Style();
        _pending.append(term.RESET);
        for (var update in updates) {
            if (update.x != x || update.y != y) {
                _pending.append(term.move_to(update.y as ulong, update.x as ulong));
            }
            if (!(update.cell.style == style)) {
                style = update.cell.style;
                _pending.append(term.RESET).append(style.to_term().sequence());
            }
            _pending.append(update.cell.symbol);
            x = update.x + display_width(update.cell.symbol).max(1);
            y = update.y;
        }
        _pending.append(term.RESET);
    }

    clear() {
        _pending.append(term.RESET).append(term.CLEAR_SCREEN);
    }

    hide_cursor() {
        _pending.append(term.HIDE_CURSOR);
    }

    show_cursor(x: int, y: int) {
        _pending.append(term.move_to(y as ulong, x as ulong)).append(term.SHOW_CURSOR);
    }

    flush() {
        if (!_pending.is_empty) {
            _out.write_all(_pending.to_string());
            _pending.clear();
        }
    }
}

## A backend that keeps the screen as a `Buffer`, for tests: draw frames to
## it, then compare `to_lines()` (and cells' styles) with what they should
## be.
##
## @example
##     import tui;
##     import [Paragraph, Terminal, TestBackend] from tui;
##
##     var backend = TestBackend(5, 1);
##     var terminal = Terminal(backend);
##     terminal.draw((frame) => {
##         frame.render_widget(Paragraph("hi"), frame.area);
##     });
##     assert(backend.to_lines()[0] == "hi   ", "drawn");
export struct TestBackend {
    ## The screen.
    var buffer: Buffer;
    ## Whether the cursor shows.
    var cursor_visible: bool;
    ## Where the cursor was last shown: column and row.
    var cursor: (int, int);

    ## Makes a blank screen of `width` columns and `height` rows.
    ##
    ## @param width the columns
    ## @param height the rows
    construct(width: int, height: int) {
        buffer = Buffer(Rect(0, 0, width, height));
        cursor_visible = true;
    }

    ## Changes the screen's size, blanking it, as a terminal window
    ## resized; the next `Terminal.draw` redraws everything.
    ##
    ## @param width the columns
    ## @param height the rows
    resize(width: int, height: int) {
        buffer = Buffer(Rect(0, 0, width, height));
    }

    ## Returns what the screen shows, a string per row.
    ##
    ## @returns the rows, top to bottom
    to_lines(): String[] {
        return buffer.to_lines();
    }
}

extend TestBackend with Backend {
    size(): Rect {
        return buffer.area;
    }

    draw(updates: CellUpdate[]) {
        for (var update in updates) {
            buffer.set(update.x, update.y, update.cell);
            # A wide character covers the next cell, as on a terminal.
            for (var x in 1..display_width(update.cell.symbol)) {
                buffer.set(update.x + x, update.y, Cell("", update.cell.style));
            }
        }
    }

    clear() {
        buffer.reset();
    }

    hide_cursor() {
        cursor_visible = false;
    }

    show_cursor(x: int, y: int) {
        cursor_visible = true;
        cursor = (x, y);
    }

    flush() {}
}

## One frame being drawn: the area of the screen and the buffer widgets
## draw into. `Terminal.draw` makes one and hands it to the app.
export struct Frame {
    ## The whole screen.
    var area: Rect;
    ## The buffer the frame is drawn into.
    var buffer: Buffer;
    var _cursor: (int, int)?;
    var _areas = HashMap<String, Rect>();

    ## Makes a frame that draws into `buffer`.
    ##
    ## @param buffer the buffer to draw into; its area is the frame's
    construct(buffer: Buffer) {
        this.buffer = buffer;
        area = buffer.area;
    }

    ## Draws `widget` into `area` of the frame. With an `id`, the area is
    ## kept, for `Terminal.area_of` to tell after the frame which widget a
    ## mouse event landed on.
    ##
    ## @param widget the widget
    ## @param area where to draw it
    ## @param id a name for the area; "" keeps none
    render_widget(widget: Widget, area: Rect, id: String = "") {
        widget.render(area, buffer);
        _keep(id, area);
    }

    ## Draws `widget` into `area` of the frame with `state`, which the
    ## widget may change. With an `id`, the area is kept, as
    ## `render_widget` keeps it.
    ##
    ## @typeParam TState the state's type
    ## @param widget the widget
    ## @param area where to draw it
    ## @param state its state
    ## @param id a name for the area; "" keeps none
    render_stateful_widget<TState>(widget: StatefulWidget<TState>, area: Rect, state: TState, id: String = "") {
        widget.render(area, buffer, state);
        _keep(id, area);
    }

    _keep(id: String, area: Rect) {
        if (!id.is_empty) {
            _areas.insert(id, area);
        }
    }

    ## Shows the cursor at column `x` and row `y` once the frame is drawn,
    ## as for a text field; it is hidden otherwise.
    ##
    ## @param x the column
    ## @param y the row
    set_cursor_position(x: int, y: int) {
        _cursor = Optional<(int, int)>.Value((x, y));
    }
}

## A screen drawn a frame at a time, in immediate mode: each `draw` has the
## app draw the whole screen from its state, and writes to the backend only
## the cells that differ from the last frame. A change of the backend's
## size is noticed at the next `draw`, which then redraws everything.
##
## @example
##     import tui;
##     import [Block, Terminal, TestBackend] from tui;
##
##     var terminal = Terminal(TestBackend(20, 5));
##     terminal.draw((frame) => {
##         frame.render_widget(Block(title = "Hello"), frame.area);
##     });
export struct Terminal {
    ## Where frames go.
    var backend: Backend;
    var _current: Buffer;
    var _previous: Buffer;
    var _cursor_hidden: bool;
    var _areas = HashMap<String, Rect>();
    var _clipboard: term.Clipboard?;

    ## Makes a terminal that draws on `backend`. The backend's screen is
    ## taken to be blank.
    ##
    ## @param backend where frames go
    construct(backend: Backend) {
        this.backend = backend;
        var area = backend.size();
        _current = Buffer(area);
        _previous = Buffer(area);
    }

    ## Returns the screen's area, as of the last `draw`.
    ##
    ## @returns the area
    size(): Rect {
        return _current.area;
    }

    ## Returns the area the last `draw` drew the widget named `id` in, as
    ## `Frame.render_widget` kept it: for hit testing a mouse event, with
    ## `Rect.contains(mouse.column, mouse.row)`.
    ##
    ## @param id the name given when drawing
    ## @returns the area, or an empty `Rect` (which contains no cell) when
    ##   the last frame drew nothing by that name
    ## @example
    ##     import tui;
    ##     import [Paragraph, Terminal, TestBackend] from tui;
    ##
    ##     var terminal = Terminal(TestBackend(20, 5));
    ##     terminal.draw((frame) => {
    ##         frame.render_widget(Paragraph("hi"), frame.area, id = "greeting");
    ##     });
    ##     var hit = terminal.area_of("greeting").contains(3, 2);   # true
    area_of(id: String): Rect {
        return _areas.try_get(id).value_or(Rect());
    }

    ## Draws a frame: calls `render` with a blank `Frame` of the whole
    ## screen, then writes to the backend the cells that changed since the
    ## last frame, and flushes once.
    ##
    ## @param render draws the frame
    ## @returns the buffer drawn, which the next frame is compared with
    draw(render: (Frame) => void): Buffer {
        var area = backend.size();
        if (!(area == _current.area)) {
            _current = Buffer(area);
            _previous = Buffer(area);
            backend.clear();
        }
        var frame = Frame(_current);
        render(frame);
        _areas = frame._areas;
        backend.draw(_current.diff(_previous));
        if (frame._cursor) {
            var (x, y) = frame._cursor.value();
            backend.show_cursor(x, y);
            _cursor_hidden = false;
        } else if (!_cursor_hidden) {
            backend.hide_cursor();
            _cursor_hidden = true;
        }
        backend.flush();
        var drawn = _current;
        _current = _previous;
        _current.reset();
        _previous = drawn;
        return drawn;
    }

    ## Copies `text` to the clipboard, through a pepper-term `Clipboard`
    ## made at the first copy (`ClipboardBackend.Auto`: the OS's clipboard
    ## when the program runs locally, else the terminal's, through OSC 52,
    ## which reaches the user's clipboard over SSH too). What the backend
    ## has not sent yet goes first, so the OSC 52 sequence is never written
    ## into the middle of a frame.
    ##
    ## Through OSC 52 the terminal does not say whether it copied, so
    ## success means the request was written.
    ##
    ## @param text the text to copy, such as a widget's `selected_text()`
    ## @returns nothing; a `ClipboardError` when there is no clipboard to
    ##   reach, the text is past the OSC 52 limit, or the OS refused. Its
    ##   `to_string()` holds none of the text, so it is safe to show
    ## @example
    ##     # in the event loop, on Ctrl+Y: copy what is selected, and say
    ##     # in a status line if that failed
    ##     var copied = terminal.copy(state.selected_text());
    ##     if (copied.is_err()) {
    ##         status = $"could not copy: {copied.error()}";
    ##     }
    copy(text: String): Result<void, term.ClipboardError> {
        backend.flush();
        if (_clipboard.is_empty()) {
            _clipboard = Optional<term.Clipboard>.Value(term.Clipboard());
        }
        return _clipboard.value().copy(text);
    }

    ## Erases the screen; the next `draw` writes every cell.
    clear() {
        backend.clear();
        backend.flush();
        _previous.reset();
    }
}

## Sets up the terminal for a full-screen app and returns a `Terminal` that
## draws on it: raw mode on, the alternate screen, colors on, the cursor
## hidden, the screen blank. With `mouse`, mouse reporting is on too, and
## `Events.next` yields `Event.Mouse`; the terminal then keeps the mouse,
## so the user cannot select text with it (many terminals still select
## with Shift held). With `paste`, bracketed paste is on too, and a paste
## arrives as one `Event.Paste` rather than as typed keys.
##
## Call `restore` when the app ends. The terminal is also restored when the
## program ends without it: at the end of `main`, on a panic, and on
## SIGTERM, SIGHUP, SIGINT or SIGQUIT (POSIX). `process.exit` runs no exit
## handlers, so call `restore` before it.
##
## Call it before anything else turns pepper-term's raw mode on (a
## `term.RawMode`, a `term.LineReader` reading a line): its signal handlers
## would then stay in place of these, and a panic would leave the alternate
## screen up. To set the terminal up again after `restore`, let the old
## `Terminal` go first: its backend's raw mode, freed later, would turn the
## new one's off.
##
## @param mouse whether to turn mouse reporting on: presses, releases,
##   drags and the wheel
## @param paste whether to turn bracketed paste on
## @returns the terminal
## @example
##     import tui;
##
##     main(): int {
##         var terminal = tui.init(mouse = true, paste = true);
##         # ... draw frames and read events ...
##         tui.restore();
##         return 0;
##     }
export init(mouse: bool = false, paste: bool = false): Terminal {
    _tui_install_hooks();
    var backend = TermBackend(mouse, paste);
    term.colors_enabled();
    _tui_enter();
    return Terminal(backend);
}

## Puts the terminal back as `init` found it: the main screen, the cursor
## showing, and raw mode, mouse reporting and bracketed paste off. Does
## nothing when it is already restored.
export restore() {
    _tui_leave();
    term.restore();
}
