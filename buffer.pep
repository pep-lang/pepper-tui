## The screen as data: a `Buffer` of `Cell`s, which widgets draw into and
## which `Terminal` compares with the last frame's to write only what
## changed.

import text;
import "geometry";
import "style";
import "text";
import "width";

## One character cell: the text it shows and its style.
##
## A wide character's cell is followed by a cell whose symbol is "", which
## the wide character covers.
[Value]
export struct Cell {
    ## What the cell shows: one character, plus any zero-width ones after
    ## it; "" for the second column of a wide character.
    var symbol: String;
    ## Its style.
    var style: Style;

    ## Makes a cell.
    ##
    ## @param symbol what it shows
    ## @param style its style
    construct(symbol: String = " ", style: Style = Style()) {
        this.symbol = symbol;
        this.style = style;
    }
}

## A rectangle of cells, row by row. Writes outside its area are dropped,
## so widgets clip without checking.
##
## @example
##     import tui;
##
##     var buffer = tui.Buffer(tui.Rect(0, 0, 5, 1));
##     buffer.set_string(1, 0, "hi", tui.Style());
##     assert(buffer.to_lines()[0] == " hi  ", "drawn at column 1");
export struct Buffer {
    ## The area the buffer covers.
    var area: Rect;
    ## The cells, row by row from the top left.
    var content: Cell[];

    ## Makes a buffer of blank cells.
    ##
    ## @param area the area it covers
    construct(area: Rect) {
        this.area = area;
        content = Array<Cell>();
        content.resize(area.area() as ulong, Cell());
    }

    ## Returns the cell at `x` and `y`.
    ##
    ## @param x the column
    ## @param y the row
    ## @returns the cell
    ## @panics if the cell is outside the area
    get(x: int, y: int): Cell {
        assert(area.contains(x, y), $"cell ({x}, {y}) is outside {area}");
        return content[_index(x, y)];
    }

    ## Sets the cell at `x` and `y`; does nothing outside the area.
    ##
    ## @param x the column
    ## @param y the row
    ## @param cell the new cell
    set(x: int, y: int, cell: Cell) {
        if (area.contains(x, y)) {
            content[_index(x, y)] = cell;
        }
    }

    _index(x: int, y: int): ulong {
        return ((y - area.y) * area.width + x - area.x) as ulong;
    }

    ## Makes every cell blank.
    reset() {
        content.fill(Cell());
    }

    ## Lays `style` over the style of every cell in `rect`.
    ##
    ## @param rect the cells to style
    ## @param style the style to lay over them
    set_style(rect: Rect, style: Style) {
        var target = rect.intersection(area);
        for (var y in target.y..target.bottom) {
            for (var x in target.x..target.right) {
                var index = _index(x, y);
                var cell = content[index];
                cell.style = cell.style.patch(style);
                content[index] = cell;
            }
        }
    }

    ## Writes `value` from `x` along row `y`, a character a cell (two for a
    ## wide one), laying `style` over each cell's, and stops before
    ## `max_width` columns or the edge. Control characters are skipped, and
    ## zero-width characters join the cell before them.
    ##
    ## @param x the first column
    ## @param y the row
    ## @param value the text
    ## @param style the style to lay over the cells
    ## @param max_width the most columns to take
    ## @returns the column after the last one written
    set_string(x: int, y: int, value: String, style: Style, max_width: int = 1000000): int {
        var limit = (x + max_width.max(0)).min(area.right);
        var column = x;
        ulong offset = 0;
        while (offset < value.size) {
            var (point, run) = text.Utf8.code_point_at(value, offset);
            var symbol = value.substr_bytes(offset, run);
            offset += run;
            var width = char_width(point);
            if (width == 0) {
                if (point >= 768 && column > x && area.contains(column - 1, y)) {
                    var last = get(column - 1, y);
                    if (last.symbol.is_empty && area.contains(column - 2, y)) {
                        last = get(column - 2, y);
                        last.symbol += symbol;
                        set(column - 2, y, last);
                    } else {
                        last.symbol += symbol;
                        set(column - 1, y, last);
                    }
                }
                continue;
            }
            if (column + width > limit) {
                break;
            }
            _put(column, y, symbol, style);
            if (width == 2) {
                _put(column + 1, y, "", style);
            }
            column += width;
        }
        return column;
    }

    _put(x: int, y: int, symbol: String, style: Style) {
        if (area.contains(x, y)) {
            var index = _index(x, y);
            var cell = content[index];
            content[index] = Cell(symbol, cell.style.patch(style));
        }
    }

    ## Writes `line` from `x` along row `y`, each span in the line's style
    ## with its own laid over it, and stops before `max_width` columns.
    ##
    ## @param x the first column
    ## @param y the row
    ## @param line the line
    ## @param max_width the most columns to take
    ## @returns the column after the last one written
    set_line(x: int, y: int, line: Line, max_width: int): int {
        var column = x;
        var end = x + max_width.max(0);
        for (var span in line.spans) {
            if (column >= end) {
                break;
            }
            column = set_string(column, y, span.content, line.style.patch(span.style), end - column);
        }
        return column;
    }

    ## Returns the cells that differ from `previous`, which covers the same
    ## area, as the updates to bring a screen showing `previous` to this
    ## buffer: each cell's column, row and the cell. A wide character's
    ## covered cell is never an update, and the cells a wide character
    ## covered in `previous` are.
    ##
    ## @param previous the buffer the screen shows now
    ## @returns the updates, row by row
    diff(previous: Buffer): CellUpdate[] {
        var updates = Array<CellUpdate>();
        var invalidated = 0;
        var to_skip = 0;
        for (ulong index in 0..content.count) {
            var current = content[index];
            var before = index < previous.content.count ? previous.content[index] : Cell("");
            var width = display_width(current.symbol);
            if ((!(current == before) || invalidated > 0) && to_skip == 0) {
                var offset = index as int;
                updates.append(CellUpdate(area.x + offset % area.width, area.y + offset / area.width, current));
            }
            to_skip = (width - 1).max(0);
            invalidated = (width.max(display_width(before.symbol)).max(invalidated) - 1).max(0);
        }
        return updates;
    }

    ## Returns each row's symbols joined, top to bottom, for checking what a
    ## buffer shows in a test. A wide character's covered cell adds nothing.
    ##
    ## @returns the rows
    to_lines(): String[] {
        var lines = Array<String>();
        for (var y in area.y..area.bottom) {
            var row = StringBuilder();
            for (var x in area.x..area.right) {
                row.append(content[_index(x, y)].symbol);
            }
            lines.append(row.to_string());
        }
        return lines;
    }

    ## Panics unless the buffer shows `expected`, a string per row, as
    ## `to_lines()` gives them: a snapshot check for tests, which prints
    ## both screens when they differ.
    ##
    ## @param expected the rows, top to bottom
    ## @panics if the rows differ, at the line of the call
    ## @example
    ##     import tui;
    ##
    ##     var buffer = tui.Buffer(tui.Rect(0, 0, 3, 1));
    ##     buffer.set_string(0, 0, "ok", tui.Style());
    ##     buffer.assert_lines(["ok "]);
    assert_lines(expected: String[], location: __ptr<char> = __caller_location()) {
        var actual = to_lines();
        if (!(actual == expected)) {
            panic($"the buffer differs\n  actual:\n{_quoted(actual)}  expected:\n{_quoted(expected)}", location);
        }
    }
}

# The rows, each quoted on a line of its own, so trailing spaces show.
_quoted(rows: String[]): String {
    var text = StringBuilder();
    for (var row in rows) {
        text.append($"    \"{row}\"\n");
    }
    return text.to_string();
}

## One cell to write to the screen: where, and what.
[Value]
export struct CellUpdate {
    ## The column.
    var x: int;
    ## The row.
    var y: int;
    ## The cell.
    var cell: Cell;

    ## Makes an update.
    ##
    ## @param x the column
    ## @param y the row
    ## @param cell the cell
    construct(x: int, y: int, cell: Cell) {
        this.x = x;
        this.y = y;
        this.cell = cell;
    }
}
