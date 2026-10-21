# Layout: each constraint, margins and spacing, and the edge cases (zero
# size, overflow, rounding).

import tui;
import [Constraint, Direction, Layout, Rect] from tui;

# The parts' sizes along the layout, as text.
sizes(constraints: Constraint[], total: int, spacing: int = 0): String {
    var parts = Layout(Direction.Horizontal, constraints, spacing = spacing).split(Rect(0, 0, total, 1));
    var widths = Array<String>();
    for (var part in parts) {
        widths.append($"{part.x}+{part.width}");
    }
    return " ".join(widths);
}

[Test]
gives_lengths_and_leaves_the_rest_empty() {
    expect_equal(sizes([Constraint.Length(3), Constraint.Length(4)], 10), "0+3 3+4");
}

[Test]
splits_by_percentage_and_ratio() {
    expect_equal(sizes([Constraint.Percentage(50), Constraint.Percentage(50)], 10), "0+5 5+5");
    expect_equal(sizes([Constraint.Ratio(1, 3), Constraint.Ratio(2, 3)], 9), "0+3 3+6");
    expect_equal(sizes([Constraint.Ratio(1, 0), Constraint.Length(2)], 9), "0+0 0+2");
}

[Test]
gives_the_rest_to_fills_by_weight() {
    expect_equal(sizes([Constraint.Length(2), Constraint.Fill(1), Constraint.Fill(2)], 11), "0+2 2+3 5+6");
    expect_equal(sizes([Constraint.Fill(1), Constraint.Fill(1), Constraint.Fill(1)], 10), "0+4 4+3 7+3");
}

[Test]
grows_mins_and_caps_maxes() {
    expect_equal(sizes([Constraint.Min(2), Constraint.Max(3)], 10), "0+7 7+3");
    expect_equal(sizes([Constraint.Min(2), Constraint.Min(2)], 9), "0+5 5+4");
    expect_equal(sizes([Constraint.Max(3), Constraint.Fill(1)], 10), "0+3 3+7");
}

[Test]
shrinks_in_proportion_when_space_is_short() {
    expect_equal(sizes([Constraint.Length(10), Constraint.Length(10)], 5), "0+3 3+2");
    expect_equal(sizes([Constraint.Length(6), Constraint.Fill(1), Constraint.Length(2)], 4), "0+3 3+0 3+1");
    expect_equal(sizes([Constraint.Percentage(80), Constraint.Percentage(80)], 10), "0+5 5+5");
}

[Test]
handles_zero_size_and_no_constraints() {
    expect_equal(sizes([Constraint.Length(3), Constraint.Fill(1)], 0), "0+0 0+0");
    expect_equal(sizes(Array<Constraint>(), 10), "");
    expect_equal(sizes([Constraint.Length(-4), Constraint.Percentage(-10)], 5), "0+0 0+0");
}

[Test]
spaces_parts_and_keeps_them_inside() {
    expect_equal(sizes([Constraint.Fill(1), Constraint.Fill(1)], 11, 1), "0+5 6+5");
    expect_equal(sizes([Constraint.Length(1), Constraint.Length(1), Constraint.Length(1)], 2, 5), "0+0 2+0 2+0");
}

[Test]
applies_margins_and_the_vertical_direction() {
    var parts = Layout(
        Direction.Vertical, [Constraint.Length(1), Constraint.Fill(1)], margin = 1
    ).split(Rect(0, 0, 10, 6));
    expect_equal(parts[0].to_string(), "Rect(1, 1, 8, 1)");
    expect_equal(parts[1].to_string(), "Rect(1, 2, 8, 3)");
    var tiny = Layout.vertical([Constraint.Fill(1)]).split(Rect(0, 0, 1, 1).inner(2, 2));
    expect_true(tiny[0].is_empty());
}

[Test]
is_deterministic() {
    var constraints = [Constraint.Ratio(1, 3), Constraint.Ratio(1, 3), Constraint.Ratio(1, 3)];
    expect_equal(sizes(constraints, 10), "0+3 3+3 6+3");
    expect_equal(sizes(constraints, 10), sizes(constraints, 10));
}
