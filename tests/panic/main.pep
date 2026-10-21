# Sets up the screen, draws a frame, then panics: tests/run.sh checks the
# screen is put back anyway.

import tui;
import [Paragraph] from tui;

main(): int {
    var terminal = tui.init();
    terminal.draw((frame) => {
        frame.render_widget(Paragraph("about to panic"), frame.area);
    });
    panic("on purpose");
    return 0;
}
