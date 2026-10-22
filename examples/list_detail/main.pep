# A list of planets on the left and the selected one's details on the
# right. Up and Down (or k and j), a click or the wheel move; q or Escape
# quits.

import term;
import [BasicColor, Color, Key] from term;
import tui;
import [
    Block, BorderType, Constraint, Event, Gauge, Layout, Line, List, ListState, Paragraph, Span, Style, Text
] from tui;

struct Planet {
    var name: String;
    var kind: String;
    var moons: int;
    # Distance from the Sun, in tenths of an astronomical unit.
    var distance: int;

    construct(name: String, kind: String, moons: int, distance: int) {
        this.name = name;
        this.kind = kind;
        this.moons = moons;
        this.distance = distance;
    }
}

planets(): Planet[] {
    return [
        Planet("Mercury", "rocky", 0, 4),
        Planet("Venus", "rocky", 0, 7),
        Planet("Earth", "rocky", 1, 10),
        Planet("Mars", "rocky", 2, 15),
        Planet("Jupiter", "gas giant", 95, 52),
        Planet("Saturn", "gas giant", 146, 95),
        Planet("Uranus", "ice giant", 28, 192),
        Planet("Neptune", "ice giant", 16, 301),
    ];
}

details(planet: Planet): Text {
    var label = Style(foreground = Color.Basic(BasicColor.Cyan), bold = true);
    return Text(
        [
            Line([Span(planet.name, Style(bold = true, underline = true))]),
            Line(""),
            Line([Span("Kind:     ", label), Span(planet.kind)]),
            Line([Span("Moons:    ", label), Span($"{planet.moons}")]),
            Line([Span("Distance: ", label), Span($"{planet.distance / 10}.{planet.distance % 10} AU")]),
        ]
    );
}

main(): int {
    var all = planets();
    var names = Array<Text>();
    for (var planet in all) {
        names.append(planet.name);
    }
    var state = ListState();
    state.select_next();
    var terminal = tui.init(mouse = true);
    var events = tui.Events();
    var running = true;
    while (running) {
        terminal.draw(
            (frame) => {
                var rows = Layout.vertical(
                    [Constraint.Fill(1), Constraint.Length(3), Constraint.Length(1)]
                ).split(frame.area);
                var columns = Layout.horizontal([Constraint.Length(16), Constraint.Fill(1)]).split(rows[0]);
                var list = List(
                    names,
                    block = Block(title = "Planets", border_type = BorderType.Rounded),
                    highlight_style = Style(foreground = Color.Basic(BasicColor.Yellow), reverse = true),
                    highlight_symbol = "> "
                );
                frame.render_stateful_widget(list, columns[0], state);
                var planet = all[state.selected.value_or(0)];
                frame.render_widget(
                    Paragraph(
                        details(planet), block = Block(title = "Details", border_type = BorderType.Rounded), wrap = true
                    ),
                    columns[1]
                );
                var outermost = all[all.count - 1].distance;
                frame.render_widget(
                    Gauge(
                        (planet.distance as double) / (outermost as double),
                        label = "distance from the Sun",
                        block = Block(),
                        gauge_style = Style(foreground = Color.Basic(BasicColor.Blue))
                    ),
                    rows[1]
                );
                frame.render_widget(
                    Paragraph("Up/Down, click or wheel move  q quit", alignment = tui.Alignment.Center), rows[2]
                );
            }
        );
        var event = events.next();
        if (event.is_empty()) {
            break;
        }
        match (event.value()) {
            Key(key) => {
                if (key.key == Key.Up || key.text == "k") {
                    state.select_previous();
                } else if (key.key == Key.Down || key.text == "j") {
                    state.select_next();
                } else if (key.key == Key.Escape || key.text == "q") {
                    running = false;
                }
            }
            Mouse(mouse) => {
                state.handle_mouse(mouse);
            }
            Resize(_, _) => {}
        }
    }
    tui.restore();
    return 0;
}
