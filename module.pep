## Full-screen terminal apps in the style of Ratatui: immediate-mode
## drawing, layout by constraints, styled text, and widgets, over
## pepper-term.
##
## Bring it in with `import tui`.
##
## - `init`, `restore`, `Terminal`, `Frame`: draw a frame at a time;
##   only the cells that changed are written
## - `Backend`, `TermBackend`, `TestBackend`: where frames go
## - `Buffer`, `Cell`, `CellUpdate`, `Rect`: the screen as data
## - `Layout`, `Constraint`, `Direction`: split an area
## - `Style`, `BOLD` and the other modifiers, `Span`, `Line`, `Text`,
##   `Alignment`, `char_width`, `display_width`: styled text
## - `Widget`, `StatefulWidget`, and the widgets `Block`, `Paragraph`,
##   `List`, `Table`, `TextInput`, `Tabs`, `Gauge`, `Sparkline`,
##   `BarChart` and `Scrollbar`
## - `Events`, `Event`: keys, the mouse (with `init(mouse = true)`),
##   pastes (with `init(paste = true)`) and resizes; `Terminal.area_of`
##   and the widgets' `handle_mouse` for hit testing
## - `Terminal.copy` and the widgets' `selected_text`: the clipboard
##
## @example
##     import tui;
##     import [Event, Paragraph] from tui;
##
##     main(): int {
##         var terminal = tui.init();
##         var events = tui.Events();
##         while (true) {
##             terminal.draw((frame) => {
##                 frame.render_widget(Paragraph("Hello! Press q to quit."), frame.area);
##             });
##             var event = events.next();
##             if (event.is_empty()) {
##                 break;
##             }
##             if (event.value() is Key(key)) {
##                 if (key.text == "q") {
##                     break;
##                 }
##             }
##         }
##         tui.restore();
##         return 0;
##     }

# This file only gathers the module's public API from its other files.

import "barchart";
import "block";
import "buffer";
import "events";
import "gauge";
import "geometry";
import "layout";
import "list";
import "paragraph";
import "scrollbar";
import "sparkline";
import "style";
import "table";
import "tabs";
import "terminal";
import "text";
import "text_input";
import "widget";
import "width";

export * from "barchart";
export * from "block";
export * from "buffer";
export * from "events";
export * from "gauge";
export * from "geometry";
export * from "layout";
export * from "list";
export * from "paragraph";
export * from "scrollbar";
export * from "sparkline";
export * from "style";
export * from "table";
export * from "tabs";
export * from "terminal";
export * from "text";
export * from "text_input";
export * from "widget";
export * from "width";
