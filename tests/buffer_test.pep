# Buffers, cells, styles and display width.

import term;
import [BasicColor, Color] from term;
import tui;
import [Buffer, Cell, Line, Rect, Span, Style] from tui;

[Test]
measures_display_width() {
    expect_equal(tui.display_width("abc"), 3);
    expect_equal(tui.display_width("界a"), 3);
    expect_equal(tui.display_width("😀"), 2);
    expect_equal(tui.display_width("é"), 1);
    expect_equal(tui.char_width(9), 0);
}

[Test]
writes_strings_and_clips_them() {
    var buffer = Buffer(Rect(0, 0, 6, 2));
    expect_equal(buffer.set_string(1, 0, "hello world", Style()), 6);
    expect_equal(buffer.set_string(0, 1, "abc", Style(), 2), 2);
    buffer.assert_lines([" hello", "ab    "]);
    buffer.set_string(-3, 5, "out", Style());
    buffer.assert_lines([" hello", "ab    "]);
}

[Test]
writes_wide_characters_as_two_cells() {
    var buffer = Buffer(Rect(0, 0, 5, 1));
    expect_equal(buffer.set_string(0, 0, "界界界", Style()), 4);
    expect_equal(buffer.get(1, 0).symbol, "");
    buffer.assert_lines(["界界 "]);
    expect_equal(tui.display_width(buffer.to_lines()[0]), 5);
}

[Test]
never_leaves_half_a_wide_character() {
    var buffer = Buffer(Rect(0, 0, 4, 1));
    buffer.set_string(2, 0, "界", Style());
    buffer.set_string(3, 0, "x", Style());
    buffer.assert_lines(["   x"]);
    buffer.set_string(0, 0, "界", Style());
    buffer.set_string(0, 0, "y", Style());
    buffer.assert_lines(["y  x"]);
    # Drawn over in a frame, the cell is sent: a scrollbar beside CJK text.
    var updates = buffer.diff(Buffer(Rect(0, 0, 4, 1)));
    expect_equal(updates.count, 2);
}

[Test]
joins_combining_marks_to_the_cell_before() {
    var buffer = Buffer(Rect(0, 0, 3, 1));
    buffer.set_string(0, 0, "éx", Style());
    expect_equal(buffer.get(0, 0).symbol, "é");
    expect_equal(buffer.get(1, 0).symbol, "x");
}

[Test]
layers_styles() {
    var red = Color.Basic(BasicColor.Red);
    var blue = Color.Basic(BasicColor.Blue);
    var base = Style(foreground = red, background = blue, bold = true);
    var top = Style(foreground = blue, italic = true).remove_modifier(tui.BOLD);
    var both = base.patch(top);
    expect_true(both.foreground.value() == blue);
    expect_true(both.background.value() == blue);
    expect_false(both.has(tui.BOLD));
    expect_true(both.has(tui.ITALIC));
    expect_equal(both.to_term().sequence(), "\x1B[3;34;44m");
    expect_true(Style().fg(Color.Default).patch(Style()).foreground.is_value());
}

[Test]
styles_lines_span_by_span() {
    var buffer = Buffer(Rect(0, 0, 4, 1));
    var line = Line([Span("a", Style(bold = true)), Span("b")], Style(italic = true));
    expect_equal(buffer.set_line(0, 0, line, 4), 2);
    expect_true(buffer.get(0, 0).style.has(tui.BOLD | tui.ITALIC));
    expect_false(buffer.get(1, 0).style.has(tui.BOLD));
    expect_true(buffer.get(1, 0).style.has(tui.ITALIC));
}

[Test]
diffs_only_changed_cells() {
    var before = Buffer(Rect(0, 0, 3, 2));
    var after = Buffer(Rect(0, 0, 3, 2));
    after.set_string(1, 1, "x", Style());
    var updates = after.diff(before);
    expect_equal(updates.count, 1);
    expect_equal(updates[0].x, 1);
    expect_equal(updates[0].y, 1);
    expect_equal(updates[0].cell.symbol, "x");
    expect_equal(after.diff(after).count, 0);
}

[Test]
diffs_wide_characters() {
    var before = Buffer(Rect(0, 0, 4, 1));
    before.set_string(0, 0, "界", Style());
    var after = Buffer(Rect(0, 0, 4, 1));
    after.set_string(0, 0, "ab", Style());
    # Both cells the wide character covered are rewritten.
    var updates = after.diff(before);
    expect_equal(updates.count, 2);
    expect_equal(updates[1].cell.symbol, "b");
    # Writing the wide character skips its covered cell.
    var back = before.diff(after);
    expect_equal(back.count, 1);
    expect_equal(back[0].cell.symbol, "界");
}
