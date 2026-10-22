# Two text fields, a name on one row and notes over many: type or paste
# into them (bracketed paste is on), select with Shift and the arrows, Tab
# moves between them, Ctrl+Y copies the selection (or the whole field) to
# the clipboard, and Escape quits.

import [Key] from term;
import tui;
import [Block, Constraint, Layout, Paragraph, Style, TextInput, TextInputState] from tui;

# The field, in a block titled `title`, with its cursor shown when it has
# the focus.
field(title: String, focused: bool): TextInput {
    return TextInput(block = Block(title = title), cursor_style = focused ? Style(reverse = true) : Style());
}

main(): int {
    var name = TextInputState();
    var notes = TextInputState(multiline = true);
    var focus = 0;
    var status = "Tab: next field  Ctrl+Y: copy  Esc: quit";
    var terminal = tui.init(paste = true);
    var events = tui.Events();
    while (true) {
        # The frame's closure keeps copies, so it gets this frame's values.
        var name_field = field("Name", focus == 0);
        var notes_field = field("Notes", focus == 1);
        var status_line = Paragraph(status);
        terminal.draw(
            (frame) => {
                var rows = Layout.vertical(
                    [Constraint.Length(3), Constraint.Fill(1), Constraint.Length(1)]
                ).split(frame.area);
                frame.render_stateful_widget(name_field, rows[0], name);
                frame.render_stateful_widget(notes_field, rows[1], notes);
                frame.render_widget(status_line, rows[2]);
            }
        );
        var event = events.next();
        if (event.is_empty()) {
            break;  # the end of input
        }
        var focused = focus == 0 ? name : notes;
        if (event.value() is Key(key)) {
            if (key.key == Key.Escape) {
                break;
            }
            if (key.key == Key.Tab) {
                focus = 1 - focus;
                continue;
            }
            if (key.ctrl && key.text == "y") {
                var text = focused.selected_text();
                if (text.is_empty) {
                    text = focused.text;
                }
                var copied = terminal.copy(text);
                status = copied.is_err() ? $"could not copy: {copied.error()}" : $"copied {text.length} characters";
                continue;
            }
        }
        focused.handle_event(event.value());
        if (event.value() is Paste(_, truncated)) {
            status = truncated ? "the paste was too long, so only its start went in" : "pasted";
        }
    }
    tui.restore();
    return 0;
}
