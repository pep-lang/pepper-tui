## Layout: `Layout` splits a `Rect` into a row or a column of smaller ones,
## sized by `Constraint`s.

import "geometry";

## Which way a layout lays its parts out.
export enum Direction {
    ## Left to right: the parts split the width.
    Horizontal,
    ## Top to bottom: the parts split the height.
    Vertical,
}

## How big one part of a layout wants to be, along the layout's direction.
[Value]
export enum Constraint {
    ## Exactly `size` cells.
    Length(size: int),
    ## At least `size` cells; it takes a share of the space left over when
    ## no part is a `Fill`.
    Min(size: int),
    ## At most `size` cells.
    Max(size: int),
    ## `percent` percent of the space, rounded down.
    Percentage(percent: int),
    ## `numerator / denominator` of the space, rounded down; nothing for a
    ## denominator of 0.
    Ratio(numerator: int, denominator: int),
    ## A share of the space left over, by `weight` against the other
    ## `Fill`s.
    Fill(weight: int),
}

## Splits a rectangle into parts along one direction, one per constraint.
##
## The solver is deterministic and never fails: each part first gets what
## its constraint asks for (a `Fill` nothing, a `Min` or a `Max` its size).
## Space left over goes to the `Fill` parts by weight or, with none, shared
## evenly by the `Min` parts, and stays empty at the end otherwise. When the
## parts ask for more than there is, every part shrinks in proportion to
## what it asked for, so all of them still fit. Rounding leftovers go to the
## first parts.
##
## @example
##     import tui;
##     import [Constraint, Direction] from tui;
##
##     var parts = tui.Layout(Direction.Vertical, [Constraint.Length(1), Constraint.Fill(1)]).split(tui.Rect(0, 0, 10, 5));
##     # parts[0] is Rect(0, 0, 10, 1); parts[1] is Rect(0, 1, 10, 4)
export struct Layout {
    ## The direction the parts follow.
    var direction: Direction;
    ## One constraint per part.
    var constraints: Constraint[];
    ## Columns left empty at the left and the right of the area.
    var horizontal_margin: int;
    ## Rows left empty at the top and the bottom of the area.
    var vertical_margin: int;
    ## Cells left empty between neighboring parts.
    var spacing: int;

    ## Makes a layout.
    ##
    ## @param direction the direction the parts follow
    ## @param constraints one constraint per part
    ## @param margin cells left empty on every side of the area
    ## @param spacing cells left empty between neighboring parts
    construct(direction: Direction, constraints: Constraint[], margin: int = 0, spacing: int = 0) {
        this.direction = direction;
        this.constraints = constraints;
        horizontal_margin = margin;
        vertical_margin = margin;
        this.spacing = spacing;
    }

    ## Makes a layout of parts top to bottom.
    ##
    ## @param constraints one constraint per part
    ## @returns the layout
    static vertical(constraints: Constraint[]): Layout {
        return Layout(Direction.Vertical, constraints);
    }

    ## Makes a layout of parts left to right.
    ##
    ## @param constraints one constraint per part
    ## @returns the layout
    static horizontal(constraints: Constraint[]): Layout {
        return Layout(Direction.Horizontal, constraints);
    }

    ## Splits `area` into one rectangle per constraint.
    ##
    ## @param area the area to split
    ## @returns the parts, in order; parts that get no space are empty
    split(area: Rect): Rect[] {
        var inner = area.inner(horizontal_margin.max(0), vertical_margin.max(0));
        var horizontal = direction == Direction.Horizontal;
        var total = horizontal ? inner.width : inner.height;
        var count = constraints.count as int;
        var gap = spacing.max(0);
        var available = (total - gap * (count - 1).max(0)).max(0);
        var sizes = _solve(constraints, available);
        var parts = Array<Rect>();
        var start = horizontal ? inner.x : inner.y;
        var end = start + total;
        for (var size in sizes) {
            var length = size.min(end - start).max(0);
            parts.append(
                horizontal ? Rect(start, inner.y, length, inner.height) : Rect(inner.x, start, inner.width, length)
            );
            start = (start + length + gap).min(end);
        }
        return parts;
    }
}

# The size of each part along the layout, which together take at most
# `available` cells.
_solve(constraints: Constraint[], available: int): int[] {
    var sizes = Array<int>();
    var asked = 0;
    for (var constraint in constraints) {
        var size = match (constraint) {
            Length(size) => size,
            Min(size) => size,
            Max(size) => size,
            Percentage(percent) => available * percent / 100,
            Ratio(numerator, denominator) => denominator == 0 ? 0 : available * numerator / denominator,
            Fill(_) => 0,
        };
        size = size.max(0);
        sizes.append(size);
        asked += size;
    }
    if (asked > available) {
        # Shrink every part in proportion to what it asked for.
        var given = 0;
        var askers = Array<ulong>();
        for (var index in 0..sizes.count) {
            if (sizes[index] > 0) {
                askers.append(index);
            }
            sizes[index] = ((sizes[index] as long) * available / asked) as int;
            given += sizes[index];
        }
        _share(sizes, askers, available - given);
        return sizes;
    }
    var spare = available - asked;
    var weights = Array<int>();
    var fills = 0;
    for (var constraint in constraints) {
        var weight = match (constraint) {
            Fill(w) => w.max(0),
            else => 0,
        };
        weights.append(weight);
        fills += weight;
    }
    if (fills > 0) {
        var given = 0;
        var takers = Array<ulong>();
        for (var index in 0..sizes.count) {
            if (weights[index] > 0) {
                var share = ((spare as long) * weights[index] / fills) as int;
                sizes[index] += share;
                given += share;
                takers.append(index);
            }
        }
        _share(sizes, takers, spare - given);
        return sizes;
    }
    var mins = Array<ulong>();
    for (var index in 0..constraints.count) {
        if (constraints[index] is Min) {
            mins.append(index);
        }
    }
    if (mins.count > 0) {
        var share = spare / mins.count as int;
        for (var index in mins) {
            sizes[index] += share;
        }
        _share(sizes, mins, spare - share * mins.count as int);
    }
    return sizes;
}

# Gives `left` more cells, one each to the parts in `takers` from the first.
_share(sizes: int[], takers: ulong[], left: int) {
    var index: ulong = 0;
    var remaining = left;
    while (remaining > 0 && takers.count > 0) {
        sizes[takers[index % takers.count]] += 1;
        remaining -= 1;
        index += 1;
    }
}
