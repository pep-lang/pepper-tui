## Rectangles of cells: `Rect`, the area a widget draws in.

## A rectangle of cells: its top-left corner, counted from 0 at the top left
## of the screen, and its size. A size below zero counts as zero.
##
## @example
##     import tui;
##
##     var area = tui.Rect(0, 0, 20, 5);
##     var inside = area.inner(1, 1);   # Rect(1, 1, 18, 3)
[Value]
export struct Rect {
    ## The leftmost column.
    var x: int;
    ## The top row.
    var y: int;
    ## The number of columns.
    var width: int;
    ## The number of rows.
    var height: int;

    ## Makes a rectangle; a negative width or height becomes 0.
    ##
    ## @param x the leftmost column
    ## @param y the top row
    ## @param width the number of columns
    ## @param height the number of rows
    construct(x: int = 0, y: int = 0, width: int = 0, height: int = 0) {
        this.x = x;
        this.y = y;
        this.width = width.max(0);
        this.height = height.max(0);
    }

    ## The column just past the right edge.
    var right: int {
        get {
            return x + width;
        }
    }

    ## The row just past the bottom edge.
    var bottom: int {
        get {
            return y + height;
        }
    }

    ## Returns the number of cells.
    ##
    ## @returns `width * height`
    area(): int {
        return width * height;
    }

    ## Returns whether the rectangle holds no cells.
    ##
    ## @returns true when the width or the height is 0
    is_empty(): bool {
        return width == 0 || height == 0;
    }

    ## Returns the rectangle shrunk by `horizontal` columns on the left and
    ## the right and `vertical` rows at the top and the bottom; empty, not
    ## negative, when the margins do not fit.
    ##
    ## @param horizontal the columns to take from each side
    ## @param vertical the rows to take from the top and the bottom
    ## @returns the smaller rectangle
    inner(horizontal: int, vertical: int): Rect {
        if (width < 2 * horizontal || height < 2 * vertical) {
            return Rect(x, y, 0, 0);
        }
        return Rect(x + horizontal, y + vertical, width - 2 * horizontal, height - 2 * vertical);
    }

    ## Returns the cells both rectangles hold.
    ##
    ## @param other the other rectangle
    ## @returns the overlap, empty when there is none
    intersection(other: Rect): Rect {
        var left = x.max(other.x);
        var top = y.max(other.y);
        return Rect(left, top, right.min(other.right) - left, bottom.min(other.bottom) - top);
    }

    ## Returns whether the cell at `column` and `row` is inside.
    ##
    ## @param column the column
    ## @param row the row
    ## @returns true when it is inside
    contains(column: int, row: int): bool {
        return column >= x && column < right && row >= y && row < bottom;
    }

    ## Returns the rectangle as "Rect(x, y, width, height)".
    ##
    ## @returns the text
    to_string(): String {
        return $"Rect({x}, {y}, {width}, {height})";
    }
}

extend Rect with ToString;
