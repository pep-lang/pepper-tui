# pepper-tui

Full-screen terminal apps for [Pepper](https://github.com/pep-lang/pepper),
modeled on [Ratatui](https://ratatui.rs): the app draws its whole screen
from its state every frame, widgets render into a buffer of cells, and only
the cells that changed since the last frame are written. It builds on
[pepper-term](https://github.com/pep-lang/pepper-term) for raw mode, keys
and colors, and works on Linux, macOS and Windows.

One module, **`tui`**:

- **`init`** sets the terminal up (raw mode, the alternate screen, the
  cursor hidden) and returns a **`Terminal`**; **`restore`** puts it back,
  and so does the end of the program, a panic included.
- **`Terminal.draw((frame) => { ... })`** draws a **`Frame`**: widgets
  render into its **`Buffer`** of **`Cell`**s, then the frame is diffed
  against the last one and written in one go.
- **`Backend`** is where frames go: **`TermBackend`** is the terminal,
  **`TestBackend`** a buffer to check in tests (`assert_lines`).
- **`Layout`** splits a **`Rect`** by **`Constraint`**s: `Length`, `Min`,
  `Max`, `Percentage`, `Ratio` and `Fill`, with margins and spacing. It is
  deterministic and never fails when space is short.
- **`Span`**, **`Line`** and **`Text`** are styled text, measured by display
  width (wide characters and emoji take two columns); **`Style`** layers
  pepper-term's colors (16, 256 and RGB) and the modifiers `BOLD`, `DIM`,
  `ITALIC`, `UNDERLINE` and `REVERSE`.
- The widgets **`Block`**, **`Paragraph`**, **`List`** and **`Table`** (with
  **`ListState`** and **`TableState`**), **`Tabs`**, **`Gauge`**,
  **`Sparkline`**, **`BarChart`** and **`Scrollbar`** (with
  **`ScrollbarState`**); the **`Widget`** and **`StatefulWidget`** traits let
  an app write its own.
- **`Events`** reads **`Event`**s: key presses and resizes.

```pepper
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
```

This is `examples/minimal/main.pep`. `examples/list_detail/main.pep` is a
list of planets beside the selected one's details, with a gauge and a help
line: `Layout`, a stateful `List`, a wrapped `Paragraph` of styled spans,
and key handling.

## Testing an app

Draw on a `TestBackend` and compare the screen, a string per row:

```pepper
import tui;
import [Block, Terminal, TestBackend] from tui;

[Test]
draws_a_titled_block() {
    var backend = TestBackend(6, 3);
    Terminal(backend).draw((frame) => {
        frame.render_widget(Block(title = "Hi"), frame.area);
    });
    backend.buffer.assert_lines(["┌Hi──┐", "│    │", "└────┘"]);
}
```

## Restoring the terminal

`restore()` leaves the alternate screen, shows the cursor and turns raw
mode off. The same happens at the end of `main`, on a panic, and, on Linux
and macOS, on SIGTERM, SIGHUP, SIGINT and SIGQUIT. `process.exit` runs no
exit handlers, so call `tui.restore()` before it.

## Limits

- No mouse, bracketed paste or focus events: pepper-term does not decode
  them (a mouse report arrives as `Key.Unknown`).
- No resize notification: pepper-term has no SIGWINCH, so `Events.next`
  notices a new size when it is called, before it waits for a key, and
  `Terminal.draw` redraws at the new size on the next frame.
- No ticks or timers: `Events.next` waits for a key with no timeout, since
  pepper-term's `KeyReader` has none
  (pep-lang/pepper-term#3).
- A panic's message is written while the alternate screen is up, so it is
  gone once the screen is put back: Pepper has no way to run code before a
  panic prints (pep-lang/pepper#83). Run the app with `2> log` to keep it.
- Display width comes from a small built-in table of wide (East Asian Wide
  and Fullwidth, and emoji) and zero-width ranges, not the full Unicode
  data, and a grapheme cluster joined by ZWJ counts each of its emoji; this
  changes to the unicode module once pep-lang/pepper#16 lands.
- `Layout` is a simple deterministic solver, not Ratatui's Cassowary one:
  leftover space goes to `Fill` parts by weight, else evenly to `Min` parts,
  else stays empty at the end; when space is short every part shrinks in
  proportion. There is no `Flex`.
- A widget takes one `Block`; a `Block` has one title, on its top border.

## Using it

This repository is a package: `pep.toml` marks its root, and its root
`module.pep` is the `tui` module. Add it to a project under the name `tui`:

```sh
pepper package add pep-lang/pepper-tui --name tui
```

which writes

```toml
[dependencies]
tui = { github = "pep-lang/pepper-tui" }
```

and fetches pepper-term with it. Colors come from pepper-term: `import
[BasicColor, Color] from term;` (add `term` as a dependency too).

## Tests

```sh
tests/run.sh path/to/pepper
```

runs the `[Test]` functions in `tests/` with `pepper test`: snapshot tests
through `TestBackend` of every widget, the layout's edge cases (zero size,
overflow, rounding), buffers, styles, display width and the diffing. Then
it builds the examples and runs them on piped input, through the real
backend, and checks the screen is put back after a panic.

## Releasing

CI (`.github/workflows/ci.yml`) runs the tests on Linux, macOS and
Windows for every push to `main` and every pull request. To release, set
`version` in `pep.toml`, merge, then push the matching tag
(`git tag v1.0.0 && git push origin v1.0.0`): CI tests the tag and
publishes a GitHub release for it. `pepper package add` and `pepper
package update` find versions by their tags.

## License

Apache-2.0; see [LICENSE](LICENSE).
