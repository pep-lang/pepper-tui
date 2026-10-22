## Input events: key presses and mouse reports from pepper-term's
## `InputReader`, and resizes of the terminal.

import term;

## Something that happened: a key pressed, the mouse used, or the terminal
## resized.
export enum Event {
    ## A key press.
    Key(key: term.KeyEvent),
    ## A mouse press, release, drag or wheel turn, which arrives only after
    ## `init(mouse = true)`. Its `column` and `row` count from 0, as a
    ## `Rect`'s do.
    Mouse(mouse: term.MouseEvent),
    ## The terminal's new size, in columns and rows.
    Resize(columns: int, rows: int),
}

## Reads events from standard input and the terminal.
##
## pepper-term sends no resize notification, so a resize is noticed when
## `next` is called: before it waits for input, and so after each event.
##
## @example
##     import tui;
##     import [Event] from tui;
##
##     var events = tui.Events();
##     var event = events.next();
##     if (event.is_value() && event.value() is Key(key)) {
##         print(key.to_string());
##     }
export struct Events {
    var _input = term.InputReader();
    var _columns: int;
    var _rows: int;

    ## Makes a reader, taking the terminal's size now as the starting one.
    construct() {
        var (columns, rows) = _size();
        _columns = columns;
        _rows = rows;
    }

    ## Waits for the next event: a resize since the last call, else the
    ## next key press or mouse report.
    ##
    ## @returns the event, or Empty at the end of input
    next(): Event? {
        var (columns, rows) = _size();
        if (columns != _columns || rows != _rows) {
            _columns = columns;
            _rows = rows;
            return Optional<Event>.Value(Event.Resize(columns, rows));
        }
        # shortcut: waits for input with no timeout, so no ticks and no
        # resize while waiting; add both once InputReader can
        # (pep-lang/pepper-term#3).
        while (true) {
            var input = _input.read();
            if (input.is_empty()) {
                return Optional<Event>.Empty;
            }
            match (input.value()) {
                Key(key) => {
                    return Optional<Event>.Value(Event.Key(key));
                }
                Mouse(mouse) => {
                    return Optional<Event>.Value(Event.Mouse(mouse));
                }
                # Pastes arrive only while a term.PasteMode is on, which this
                # package never turns on; pep-lang/pepper-tui#3 adds them.
                Paste(_, _) => {}
            }
        }
    }
}

_size(): (int, int) {
    var size = term.size();
    if (size.is_empty()) {
        return (0, 0);
    }
    return (size.value().columns as int, size.value().rows as int);
}

# Whether `event` is a press of the left button: what selects.
_is_left_click(event: term.MouseEvent): bool {
    return event.kind == term.MouseKind.Down && event.button == term.MouseButton.Left;
}
