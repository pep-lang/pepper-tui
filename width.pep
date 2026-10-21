## Display width: how many terminal columns a character or a string takes.
## Wide characters (CJK, Hangul, fullwidth forms, most emoji) take two,
## combining marks and other zero-width characters none, and every other
## printable character one.

import text;

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
    # shortcut: a hand-picked subset of Unicode's East Asian Width (W and F)
    # and emoji ranges, not the full tables; switch to the unicode module
    # once pep-lang/pepper#16 lands.
    return match (code_point) {
        0..32, 127..160 => 0,
        768..880, 1155..1162, 1425..1470, 8203..8208, 8288..8293, 8400..8433, 65024..65040, 65056..65072 => 0,
        4352..4448, 8986..8988, 9193..9197, 9200, 9203, 9725..9727, 9748..9750, 9800..9812 => 2,
        9855, 9875, 9889, 9898..9900, 9917..9919, 9924..9926, 9934, 9940, 9962, 9970..9972, 9973 => 2,
        9978, 9981, 9989, 9994..9996, 10024, 10060, 10062, 10067..10070, 10071, 10133..10136 => 2,
        10160, 10175, 11035..11037, 11088, 11093, 11904..12351, 12353..13312, 13312..19904 => 2,
        19968..40960, 40960..42192, 44032..55204, 63744..64256, 65072..65104, 65280..65377 => 2,
        65504..65511, 110592..111360, 126980, 127183, 127374, 127377..127387 => 2,
        127744..128592, 128640..128768, 128992..129004, 129280..129536, 129648..129792 => 2,
        131072..196606, 196608..262142 => 2,
        else => 1,
    };
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
    var width = 0;
    ulong offset = 0;
    while (offset < value.size) {
        var (point, run) = text.Utf8.code_point_at(value, offset);
        width += char_width(point);
        offset += run;
    }
    return width;
}
