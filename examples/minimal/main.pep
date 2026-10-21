# The smallest full-screen app: a bordered greeting, until q is pressed.

import tui;
import [Block, Event, Paragraph] from tui;

main(): int {
    var terminal = tui.init();
    var events = tui.Events();
    while (true) {
        terminal.draw(
            (frame) => {
                frame.render_widget(
                    Paragraph("Hello, world! Press q to quit.", block = Block(title = "Minimal")), frame.area
                );
            }
        );
        var event = events.next();
        if (event.is_empty()) {
            break;  # the end of input
        }
        if (event.value() is Key(key)) {
            if (key.text == "q") {
                break;
            }
        }
    }
    tui.restore();
    return 0;
}
