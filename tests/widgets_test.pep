# Snapshot tests of every widget, drawn through a Terminal on a TestBackend.

import [MouseButton, MouseEvent, MouseKind] from term;
import tui;
import [
    Alignment,
    BarChart,
    Block,
    BorderType,
    Buffer,
    Constraint,
    Frame,
    Gauge,
    Line,
    List,
    ListState,
    Paragraph,
    Rect,
    Row,
    Scrollbar,
    ScrollbarOrientation,
    ScrollbarState,
    StatefulWidget,
    Sparkline,
    Table,
    TableState,
    Tabs,
    Terminal,
    TestBackend,
    Text,
    Widget
] from tui;

# The screen after drawing `widget` over the whole of a `width` by `height`
# terminal.
draw(widget: Widget, width: int, height: int): Buffer {
    var backend = TestBackend(width, height);
    Terminal(backend).draw((frame) => {
        frame.render_widget(widget, frame.area);
    });
    return backend.buffer;
}

# The screen after drawing `widget` with `state`, as `draw` does.
draw_stateful<TState>(widget: StatefulWidget<TState>, state: TState, width: int, height: int): Buffer {
    var backend = TestBackend(width, height);
    Terminal(backend).draw((frame) => {
        frame.render_stateful_widget(widget, frame.area, state);
    });
    return backend.buffer;
}

[Test]
block_draws_borders_and_a_title() {
    draw(Block(title = "Hi"), 6, 3).assert_lines(["┌Hi──┐", "│    │", "└────┘"]);
    draw(
        Block(title = "ab", border_type = BorderType.Rounded, title_alignment = Alignment.Center), 8, 2
    ).assert_lines(["╭──ab──╮", "╰──────╯"]);
    draw(
        Block(borders = tui.BORDER_TOP | tui.BORDER_BOTTOM, border_type = BorderType.Double), 4, 3
    ).assert_lines(["════", "    ", "════"]);
    draw(Block(title = "abcdefgh", border_type = BorderType.Thick), 6, 2).assert_lines(["┏abcd┓", "┗━━━━┛"]);
}

[Test]
block_handles_tiny_areas() {
    draw(Block(), 1, 1).assert_lines(["┘"]);
    draw(Block(), 0, 0).assert_lines(Array<String>());
    expect_true(Block().inner(Rect(0, 0, 1, 1)).is_empty());
    expect_equal(Block(padding = 1).inner(Rect(0, 0, 10, 6)).to_string(), "Rect(2, 2, 6, 2)");
    expect_equal(Block(borders = tui.BORDER_NONE).inner(Rect(1, 2, 3, 4)).to_string(), "Rect(1, 2, 3, 4)");
}

[Test]
paragraph_cuts_lines_at_the_edge() {
    draw(Paragraph("hello world\nsecond"), 8, 3).assert_lines(["hello wo", "second  ", "        "]);
}

[Test]
paragraph_wraps_at_spaces_and_breaks_long_words() {
    draw(Paragraph("hello world again", wrap = true), 8, 3).assert_lines(["hello   ", "world   ", "again   "]);
    draw(Paragraph("abcdefghij", wrap = true), 4, 3).assert_lines(["abcd", "efgh", "ij  "]);
    draw(Paragraph("界界界", wrap = true), 5, 2).assert_lines(["界界 ", "界   "]);
    draw(Paragraph("  ab", wrap = true), 4, 1).assert_lines(["ab  "]);
    draw(Paragraph("  ab", wrap = true, trim = false), 4, 1).assert_lines(["  ab"]);
    expect_equal(Paragraph("hello world again", wrap = true).line_count(8), 3);
}

[Test]
paragraph_aligns_scrolls_and_sits_in_a_block() {
    var text = Text([Line("ab"), Line("cd").aligned(Alignment.Right)]);
    draw(Paragraph(text, alignment = Alignment.Center), 6, 2).assert_lines(["  ab  ", "    cd"]);
    draw(Paragraph("1\n2\n3\n4", scroll = 2), 3, 2).assert_lines(["3  ", "4  "]);
    draw(Paragraph("1", scroll = 9), 3, 1).assert_lines(["   "]);
    draw(Paragraph("hi", block = Block(title = "T")), 5, 3).assert_lines(["┌T──┐", "│hi │", "└───┘"]);
}

[Test]
list_highlights_the_selection() {
    var list = List(["one", "two", "three"], highlight_symbol = ">");
    var state = ListState();
    state.select(Optional<ulong>.Value(1));
    var buffer = draw_stateful(list, state, 6, 3);
    buffer.assert_lines([" one  ", ">two  ", " three"]);
    expect_true(buffer.get(0, 1).style.has(tui.REVERSE));
    expect_true(buffer.get(5, 1).style.has(tui.REVERSE));
    expect_false(buffer.get(0, 0).style.has(tui.REVERSE));
    draw(List(["a", "b"]), 3, 2).assert_lines(["a  ", "b  "]);
}

[Test]
list_scrolls_to_the_selection() {
    var list = List(["a", "b", "c", "d", "e"]);
    var state = ListState();
    state.select(Optional<ulong>.Value(4));
    draw_stateful(list, state, 1, 2).assert_lines(["d", "e"]);
    expect_equal(state.offset, 3);
    state.select(Optional<ulong>.Value(0));
    draw_stateful(list, state, 1, 2).assert_lines(["a", "b"]);
    expect_equal(state.offset, 0);
}

[Test]
list_keeps_the_selection_in_range() {
    var state = ListState();
    state.select(Optional<ulong>.Value(10));
    draw_stateful(List(["a", "b", "c"]), state, 1, 3);
    expect_equal(state.selected.value(), 2);
    state.select_next();
    draw_stateful(List(["a", "b", "c"]), state, 1, 3);
    expect_equal(state.selected.value(), 2);
    state.select_previous();
    expect_equal(state.selected.value(), 1);
    draw_stateful(List(Array<Text>()), state, 1, 3).assert_lines([" ", " ", " "]);
    expect_true(state.selected.is_empty());
}

[Test]
table_lays_out_columns_with_a_header() {
    var rows = [Row(["Ada", "1815"]), Row(["Grace", "1906"])];
    var widths = [Constraint.Length(5), Constraint.Length(4)];
    draw(
        Table(rows, widths, header = Row(["Name", "Born"])), 10, 3
    ).assert_lines(["Name  Born", "Ada   1815", "Grace 1906"]);
    var state = TableState();
    state.select(Optional<ulong>.Value(1));
    var buffer = draw_stateful(
        Table(rows, widths, header = Row(["Name", "Born"]), highlight_symbol = ">>"), state, 12, 3
    );
    buffer.assert_lines(["  Name  Born", "  Ada   1815", ">>Grace 1906"]);
    expect_true(buffer.get(11, 2).style.has(tui.REVERSE));
}

[Test]
table_scrolls_below_its_header() {
    var rows = [Row(["1"]), Row(["2"]), Row(["3"]), Row(["4"])];
    var state = TableState();
    state.select(Optional<ulong>.Value(3));
    draw_stateful(Table(rows, [Constraint.Fill(1)], header = Row(["#"])), state, 2, 3).assert_lines(["# ", "3 ", "4 "]);
    expect_equal(state.offset, 2);
    draw_stateful(Table(rows, [Constraint.Fill(1)]), state, 2, 0).assert_lines(Array<String>());
}

[Test]
tabs_divide_titles_and_highlight_one() {
    var buffer = draw(Tabs(["A", "Bc", "D"], selected = 1), 12, 1);
    buffer.assert_lines([" A │ Bc │ D "]);
    expect_true(buffer.get(5, 0).style.has(tui.REVERSE));
    expect_false(buffer.get(4, 0).style.has(tui.REVERSE));
    expect_false(buffer.get(7, 0).style.has(tui.REVERSE));
    draw(Tabs(["A", "Bc", "D"]), 5, 1).assert_lines([" A │ "]);
}

[Test]
gauge_fills_to_its_ratio() {
    var buffer = draw(Gauge(0.5), 10, 1);
    buffer.assert_lines(["███50%    "]);
    expect_true(buffer.get(3, 0).style.has(tui.REVERSE));
    expect_false(buffer.get(5, 0).style.has(tui.REVERSE));
    draw(Gauge(0.25, use_unicode = true), 5, 3).assert_lines(["█▎   ", "█25% ", "█▎   "]);
    draw(Gauge(2.0, label = "done"), 6, 1).assert_lines(["█done█"]);
    draw(Gauge(-1.0), 4, 1).assert_lines([" 0% "]);
}

[Test]
sparkline_draws_a_bar_per_value() {
    draw(Sparkline([0, 1, 2, 4, 8]), 5, 1).assert_lines([" ▁▂▄█"]);
    draw(Sparkline([0, 1, 2, 4, 8]), 5, 2).assert_lines(["    █", " ▂▄██"]);
    draw(Sparkline([8, 8, 8, 8, 8, 8, 8]), 3, 1).assert_lines(["███"]);
    draw(Sparkline([5, 10], max = 20), 2, 1).assert_lines(["▂▄"]);
    draw(Sparkline(Array<ulong>()), 2, 1).assert_lines(["  "]);
}

[Test]
barchart_draws_labeled_bars() {
    draw(BarChart([("a", 2), ("b", 4)]), 4, 3).assert_lines(["  █ ", "2 4 ", "a b "]);
    draw(
        BarChart([("Mon", 3), ("Tue", 7)], bar_width = 3), 7, 4
    ).assert_lines(["    ███", "▂▂▂ ███", "█3█ █7█", "Mon Tue"]);
    draw(BarChart([("a", 1), ("b", 1), ("c", 1)]), 3, 2).assert_lines(["1 1", "a b"]);
}

[Test]
scrollbar_places_its_thumb() {
    var bar = Scrollbar();
    draw_stateful(bar, ScrollbarState(10, 0, 4), 3, 6).assert_lines(["  ▲", "  █", "  ║", "  ║", "  ║", "  ▼"]);
    draw_stateful(bar, ScrollbarState(10, 6, 4), 3, 6).assert_lines(["  ▲", "  ║", "  ║", "  ║", "  █", "  ▼"]);
    draw_stateful(
        Scrollbar(ScrollbarOrientation.HorizontalBottom), ScrollbarState(2, 0, 4), 6, 2
    ).assert_lines(["      ", "◄████►"]);
    draw_stateful(bar, ScrollbarState(0), 1, 3).assert_lines([" ", " ", " "]);
    # Over a wide character's covered cell, the arrow still shows.
    var backend = TestBackend(4, 3);
    Terminal(backend).draw((frame) => {
        frame.render_widget(Paragraph("ab界"), frame.area);
        frame.render_stateful_widget(bar, frame.area, ScrollbarState(10));
    });
    backend.buffer.assert_lines(["ab ▲", "   █", "   ▼"]);
    draw_stateful(Scrollbar(ScrollbarOrientation.VerticalLeft), ScrollbarState(5), 2, 2).assert_lines(["█ ", "║ "]);
}

# Mouse events, as `Event.Mouse` gives them.

click(column: int, row: int): MouseEvent {
    return MouseEvent(MouseKind.Down, MouseButton.Left, column as ulong, row as ulong);
}

mouse(kind: MouseKind, column: int, row: int): MouseEvent {
    return MouseEvent(kind, MouseButton.None, column as ulong, row as ulong);
}

[Test]
list_selects_by_click_and_wheel() {
    var list = List(["a", "b", "c", "d", "e"], block = Block(), highlight_symbol = ">");
    var state = ListState();
    expect_false(state.handle_mouse(click(1, 1)));  # not drawn yet
    draw_stateful(list, state, 5, 4).assert_lines(["┌───┐", "│a  │", "│b  │", "└───┘"]);
    expect_true(state.handle_mouse(click(1, 2)));
    draw_stateful(list, state, 5, 4).assert_lines(["┌───┐", "│ a │", "│>b │", "└───┘"]);
    # The borders, outside, and other buttons select nothing.
    expect_false(state.handle_mouse(click(0, 1)));
    expect_false(state.handle_mouse(click(1, 0)));
    expect_false(state.handle_mouse(click(9, 9)));
    expect_false(state.handle_mouse(MouseEvent(MouseKind.Down, MouseButton.Right, 1, 1)));
    expect_false(state.handle_mouse(mouse(MouseKind.ScrollDown, 9, 9)));
    expect_equal(state.selected.value(), 1);
    # The wheel anywhere over the list, borders included, moves the selection.
    expect_true(state.handle_mouse(mouse(MouseKind.ScrollDown, 0, 0)));
    draw_stateful(list, state, 5, 4).assert_lines(["┌───┐", "│ b │", "│>c │", "└───┘"]);
    for (var _ in 0..10) {
        state.handle_mouse(mouse(MouseKind.ScrollDown, 2, 2));
    }
    expect_equal(state.selected.value(), 4);
    expect_true(state.handle_mouse(mouse(MouseKind.ScrollUp, 2, 2)));
    expect_equal(state.selected.value(), 3);
    # A click on a row past the last item selects nothing.
    var short = ListState();
    draw_stateful(List(["a"]), short, 1, 3);
    expect_false(short.handle_mouse(click(0, 2)));
    expect_true(short.selected.is_empty());
}

[Test]
list_selects_a_partly_shown_last_item() {
    var list = List([Text("a1\na2"), Text("b1\nb2")]);
    var state = ListState();
    draw_stateful(list, state, 2, 3).assert_lines(["a1", "a2", "b1"]);
    expect_true(state.handle_mouse(click(0, 2)));
    expect_equal(state.selected.value(), 1);
    draw_stateful(list, state, 2, 3).assert_lines(["b1", "b2", "  "]);
}

[Test]
table_selects_rows_and_reports_header_clicks() {
    var rows = [Row(["a", "1"]), Row(["b", "2"])];
    var table = Table(rows, [Constraint.Length(1), Constraint.Length(1)], header = Row(["N", "V"]));
    var state = TableState();
    draw_stateful(table, state, 3, 3).assert_lines(["N V", "a 1", "b 2"]);
    expect_false(state.handle_mouse(click(2, 0)));
    expect_equal(state.header_clicked(click(2, 0)).value(), 1);
    expect_equal(state.header_clicked(click(0, 0)).value(), 0);
    expect_true(state.header_clicked(click(1, 0)).is_empty());  # the spacing
    expect_true(state.header_clicked(click(0, 1)).is_empty());
    expect_true(state.selected.is_empty());
    expect_true(state.handle_mouse(click(2, 2)));
    var buffer = draw_stateful(table, state, 3, 3);
    expect_equal(state.selected.value(), 1);
    expect_true(buffer.get(0, 2).style.has(tui.REVERSE));
}

[Test]
tabs_select_by_click() {
    var tabs = Tabs(["ab", "cd"]);
    var area = Rect(0, 0, 9, 1);
    expect_false(tabs.handle_mouse(click(4, 0), area));  # the divider
    expect_false(tabs.handle_mouse(click(9, 0), area));
    expect_true(tabs.handle_mouse(click(5, 0), area));  # the padding
    expect_equal(tabs.selected, 1);
    var buffer = draw(tabs, 9, 1);
    buffer.assert_lines([" ab │ cd "]);
    expect_true(buffer.get(6, 0).style.has(tui.REVERSE));
    expect_false(buffer.get(1, 0).style.has(tui.REVERSE));
    expect_true(tabs.handle_mouse(click(0, 0), area));
    expect_equal(tabs.selected, 0);
}

[Test]
scrollbar_jumps_on_a_click_and_follows_a_drag() {
    var bar = Scrollbar();
    var state = ScrollbarState(100);
    var area = Rect(0, 0, 1, 12);
    draw_stateful(bar, state, 1, 12);
    # The track is rows 1 to 10, with the thumb one row long.
    expect_true(state.handle_mouse(click(0, 10), area));
    expect_equal(state.position, 90);
    expect_true(state.handle_mouse(mouse(MouseKind.Up, 0, 10), area));
    expect_false(state.handle_mouse(click(0, 11), area));  # the arrow
    expect_true(state.handle_mouse(click(0, 1), area));
    expect_equal(state.position, 0);
    # Still held: dragging moves the thumb, off the bar too.
    expect_true(state.handle_mouse(mouse(MouseKind.Drag, 5, 5), area));
    expect_equal(state.position, 40);
    expect_true(state.handle_mouse(mouse(MouseKind.Up, 5, 5), area));
    expect_false(state.handle_mouse(mouse(MouseKind.Drag, 5, 8), area));
    draw_stateful(bar, state, 1, 12).assert_lines(["▲", "║", "║", "║", "║", "█", "║", "║", "║", "║", "║", "▼"]);
    expect_true(state.handle_mouse(mouse(MouseKind.ScrollDown, 0, 3), area));
    expect_equal(state.position, 41);
}

[Test]
paragraph_scrolls_with_the_wheel() {
    var text = Text("1\n2\n3\n4");
    var state = ScrollbarState(Paragraph(text).line_count(3), viewport_content_length = 2);
    var area = Rect(0, 0, 3, 2);
    expect_false(state.handle_mouse(mouse(MouseKind.ScrollDown, 3, 0), area));
    for (var _ in 0..3) {
        expect_true(state.handle_mouse(mouse(MouseKind.ScrollDown, 1, 1), area));
    }
    expect_equal(state.position, 2);
    draw(Paragraph(text, scroll = state.position), 3, 2).assert_lines(["3  ", "4  "]);
    expect_true(state.handle_mouse(mouse(MouseKind.ScrollUp, 1, 1), area));
    draw(Paragraph(text, scroll = state.position), 3, 2).assert_lines(["2  ", "3  "]);
}

# A widget an app writes itself.
struct Checker {}

extend Checker with Widget {
    render(area: Rect, buffer: Buffer) {
        for (var y in area.y..area.bottom) {
            for (var x in area.x..area.right) {
                buffer.set_string(x, y, (x + y) % 2 == 0 ? "#" : ".", tui.Style());
            }
        }
    }
}

[Test]
draws_an_apps_own_widget() {
    var backend = TestBackend(5, 3);
    Terminal(backend).draw((frame) => {
        frame.render_widget(Block(), frame.area);
        frame.render_widget(Checker(), Block().inner(frame.area));
    });
    backend.buffer.assert_lines(["┌───┐", "│#.#│", "└───┘"]);
}
