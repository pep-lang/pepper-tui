## `Table`: rows of cells in columns sized by constraints, with a header and
## a selected row, scrolled like a `List`.

import "block";
import "buffer";
import "geometry";
import "layout";
import "list";
import "style";
import "text";
import "widget";
import "width";

## One row of a `Table`: a `Text` per column.
export struct Row {
    ## The cells, left to right.
    var cells: Text[];
    ## The style of the whole row.
    var style: Style;
    ## The number of rows of the screen it takes.
    var height: int;

    ## Makes a row.
    ##
    ## @param cells the cells, left to right
    ## @param style the style of the whole row
    ## @param height the rows of the screen it takes
    construct(cells: Text[], style: Style = Style(), height: int = 1) {
        this.cells = cells;
        this.style = style;
        this.height = height;
    }
}

## Rows of cells in columns, with an optional header row and the selected
## row highlighted. `widths` sizes the columns as a horizontal `Layout`
## does, with `column_spacing` between them.
##
## As a `StatefulWidget<TableState>` it draws the selection and scrolls to
## it; as a `Widget` it draws the rows from the top with none selected.
##
## @example
##     import tui;
##     import [Constraint, Row, Table, TableState] from tui;
##
##     var table = Table(
##         [Row(["Ada", "1815"]), Row(["Grace", "1906"])],
##         [Constraint.Length(6), Constraint.Length(4)],
##         header = Row(["Name", "Born"])
##     );
export struct Table {
    ## The rows, top to bottom.
    var rows: Row[];
    ## One constraint per column.
    var widths: Constraint[];
    ## The header, drawn above the rows; a row with no cells for none.
    var header: Row;
    ## The block around the table; borderless by default.
    var block: Block;
    ## The style of the whole area.
    var style: Style;
    ## Columns left empty between neighboring columns.
    var column_spacing: int;
    ## The style laid over the selected row.
    var highlight_style: Style;
    ## Drawn before the selected row; the other rows are indented by its
    ## width while a row is selected.
    var highlight_symbol: String;

    ## Makes a table.
    ##
    ## @param rows the rows, top to bottom
    ## @param widths one constraint per column
    ## @param header the header row; one with no cells for none
    ## @param block the block around the table
    ## @param style the style of the whole area
    ## @param column_spacing columns between columns
    ## @param highlight_style the style of the selected row
    ## @param highlight_symbol the mark before the selected row
    construct(
        rows: Row[],
        widths: Constraint[],
        header: Row = Row(Array<Text>()),
        block: Block = Block(borders = BORDER_NONE),
        style: Style = Style(),
        column_spacing: int = 1,
        highlight_style: Style = Style(reverse = true),
        highlight_symbol: String = ""
    ) {
        this.rows = rows;
        this.widths = widths;
        this.header = header;
        this.block = block;
        this.style = style;
        this.column_spacing = column_spacing;
        this.highlight_style = highlight_style;
        this.highlight_symbol = highlight_symbol;
    }

    _draw_row(buffer: Buffer, row: Row, columns: Rect[], y: int, height: int) {
        if (columns.count > 0) {
            var first = columns[0];
            var last = columns[columns.count - 1];
            buffer.set_style(Rect(first.x, y, last.right - first.x, height), row.style);
        }
        var count = row.cells.count.min(columns.count);
        for (ulong column in 0..count) {
            var cell = row.cells[column];
            var area = columns[column];
            var lines = cell.lines.count.min(height as ulong);
            for (ulong line in 0..lines) {
                buffer.set_line(area.x, y + line as int, cell.lines[line], area.width);
            }
        }
    }
}

extend Table with StatefulWidget<TableState> {
    render(area: Rect, buffer: Buffer, state: TableState) {
        buffer.set_style(area, style);
        block.render(area, buffer);
        var inner = block.inner(area);
        if (inner.is_empty()) {
            return;
        }
        if (rows.count == 0) {
            state.select(Optional<ulong>.Empty);
        } else {
            _clamp_selection(state, rows.count);
        }
        var mark = state.selected ? display_width(highlight_symbol) : 0;
        var columns = Layout(Direction.Horizontal, widths, spacing = column_spacing).split(
            Rect(inner.x + mark, inner.y, inner.width - mark, 1)
        );
        var y = inner.y;
        if (header.cells.count > 0) {
            var height = header.height.max(1).min(inner.height);
            _draw_row(buffer, header, columns, y, height);
            y += height;
        }
        if (rows.count == 0) {
            return;
        }
        var heights = Array<int>();
        for (var row in rows) {
            heights.append(row.height.max(1));
        }
        state.offset = _visible_offset(heights, state, inner.bottom - y);
        var index = state.offset;
        while (index < rows.count && y < inner.bottom) {
            var height = heights[index].min(inner.bottom - y);
            _draw_row(buffer, rows[index], columns, y, height);
            if (state.selected && state.selected.value() == index) {
                buffer.set_string(inner.x, y, highlight_symbol, Style(), mark);
                buffer.set_style(Rect(inner.x, y, inner.width, height), highlight_style);
            }
            y += height;
            index += 1;
        }
    }
}

extend Table with Widget {
    render(area: Rect, buffer: Buffer) {
        render(area, buffer, TableState());
    }
}
