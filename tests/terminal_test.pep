# The Terminal: diffed frames, resizes and the cursor.

import tui;
import [Backend, CellUpdate, Paragraph, Rect, Terminal, TestBackend, Text] from tui;

# A backend that counts the cells each frame writes.
struct Recorder {
    var screen = TestBackend(4, 2);
    var written = Array<int>();
}

extend Recorder with Backend {
    size(): Rect {
        return screen.size();
    }

    draw(updates: CellUpdate[]) {
        written.append(updates.count as int);
        screen.draw(updates);
    }

    clear() {
        screen.clear();
    }

    hide_cursor() {
        screen.hide_cursor();
    }

    show_cursor(x: int, y: int) {
        screen.show_cursor(x, y);
    }

    flush() {}
}

show(terminal: Terminal, text: Text) {
    terminal.draw((frame) => {
        frame.render_widget(Paragraph(text), frame.area);
    });
}

[Test]
writes_only_the_cells_that_changed() {
    var recorder = Recorder();
    var terminal = Terminal(recorder);
    show(terminal, "ab\ncd");
    show(terminal, "ab\ncd");
    show(terminal, "ax\ncd");
    show(terminal, "a\n");
    expect_equal(recorder.written[0], 4);
    expect_equal(recorder.written[1], 0);
    expect_equal(recorder.written[2], 1);
    expect_equal(recorder.written[3], 3);
    recorder.screen.buffer.assert_lines(["a   ", "    "]);
}

[Test]
redraws_everything_after_a_resize_or_a_clear() {
    var backend = TestBackend(4, 1);
    var terminal = Terminal(backend);
    show(terminal, "abcdef");
    backend.buffer.assert_lines(["abcd"]);
    backend.resize(6, 2);
    show(terminal, "abcdef");
    backend.buffer.assert_lines(["abcdef", "      "]);
    expect_equal(terminal.size().to_string(), "Rect(0, 0, 6, 2)");
    terminal.clear();
    backend.buffer.assert_lines(["      ", "      "]);
    show(terminal, "abcdef");
    backend.buffer.assert_lines(["abcdef", "      "]);
    backend.resize(0, 0);
    show(terminal, "abcdef");
    backend.buffer.assert_lines(Array<String>());
}

[Test]
shows_the_cursor_only_when_a_frame_places_it() {
    var backend = TestBackend(4, 2);
    var terminal = Terminal(backend);
    show(terminal, "");
    expect_false(backend.cursor_visible);
    terminal.draw((frame) => {
        frame.set_cursor_position(2, 1);
    });
    expect_true(backend.cursor_visible);
    expect_equal(backend.cursor, (2, 1));
    show(terminal, "");
    expect_false(backend.cursor_visible);
}

[Test]
returns_the_frame_it_drew() {
    var terminal = Terminal(TestBackend(3, 1));
    var drawn = terminal.draw((frame) => {
        frame.render_widget(Paragraph("hey"), frame.area);
    });
    drawn.assert_lines(["hey"]);
}
