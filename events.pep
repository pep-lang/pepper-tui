## Input events: key presses from pepper-term's `KeyReader`, and resizes of
## the terminal.

import term;

## Something that happened: a key pressed or the terminal resized.
export enum Event {
    ## A key press.
    Key(key: term.KeyEvent),
    ## The terminal's new size, in columns and rows.
    Resize(columns: int, rows: int),
}

## Reads events from standard input and the terminal.
##
## pepper-term sends no resize notification, so a resize is noticed when
## `next` is called: before it waits for a key, and so after each one.
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
    var _keys = term.KeyReader();
    var _columns: int;
    var _rows: int;

    ## Makes a reader, taking the terminal's size now as the starting one.
    construct() {
        var (columns, rows) = _size();
        _columns = columns;
        _rows = rows;
    }

    ## Waits for the next event: a resize since the last call, else the
    ## next key press.
    ##
    ## @returns the event, or Empty at the end of input
    next(): Event? {
        var (columns, rows) = _size();
        if (columns != _columns || rows != _rows) {
            _columns = columns;
            _rows = rows;
            return Optional<Event>.Value(Event.Resize(columns, rows));
        }
        # shortcut: waits for a key with no timeout, so no ticks and no resize
        # while waiting; add both once KeyReader can (pep-lang/pepper-term#3).
        var key = _keys.read();
        if (key.is_empty()) {
            return Optional<Event>.Empty;
        }
        return Optional<Event>.Value(Event.Key(key.value()));
    }
}

_size(): (int, int) {
    var size = term.size();
    if (size.is_empty()) {
        return (0, 0);
    }
    return (size.value().columns as int, size.value().rows as int);
}
