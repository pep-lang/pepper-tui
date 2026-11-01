## Display width: how many terminal columns a character or a string takes.
## Wide characters (CJK, Hangul, fullwidth forms, most emoji) take two,
## combining marks and other zero-width characters none, and every other
## printable character one, from Unicode's tables (pepper-unicode).

import unicode;

## Returns the number of columns `code_point` takes on a terminal: 2 for a
## wide character, 0 for a combining mark, a zero-width character or a
## control character, and 1 otherwise.
##
## @param code_point the Unicode code point
## @returns 0, 1 or 2
## @example
##     import tui;
##
##     assert(tui.char_width(97) == 1, "'a'");
##     assert(tui.char_width(30028) == 2, "'界'");
export char_width(code_point: uint): int {
    return unicode.code_point_width(code_point) as int;
}

## Returns the number of columns `text` takes on a terminal: the sum of
## `char_width` over its code points.
##
## @param value the text to measure
## @returns the width in columns
## @example
##     import tui;
##
##     assert(tui.display_width("ab界") == 4, "two narrow, one wide");
export display_width(value: String): int {
    return unicode.display_width(value) as int;
}
