## Styles that layer: a `Style` sets only some of a cell's colors and
## modifiers, and `patch` lays one style over another, so a widget's style,
## a line's and a span's combine as Ratatui's do. Colors are pepper-term's
## `Color`: the 16 basic colors, the 256 indexed ones, and RGB.

import term;
import [Color] from term;

## The bold modifier, for `Style.add_modifiers` and `Style.remove_modifiers`.
export const BOLD = 1;
## The dim (faint) modifier.
export const DIM = 2;
## The italic modifier.
export const ITALIC = 4;
## The underline modifier.
export const UNDERLINE = 8;
## The reversed modifier: foreground and background swapped.
export const REVERSE = 16;

## Some of a cell's colors and modifiers. What a style leaves unset comes
## from the style beneath it when `patch` lays it over another.
##
## @example
##     import tui;
##     import term;
##     import [BasicColor, Color] from term;
##
##     var base = tui.Style(foreground = Color.Basic(BasicColor.White), bold = true);
##     var warning = tui.Style(foreground = Color.Basic(BasicColor.Yellow));
##     var both = base.patch(warning);   # yellow and bold
[Value]
export struct Style {
    ## The text color, or Empty to keep the one beneath.
    var foreground: Color?;
    ## The background color, or Empty to keep the one beneath.
    var background: Color?;
    ## The modifiers this style turns on: `BOLD`, `DIM`, `ITALIC`,
    ## `UNDERLINE` and `REVERSE`, or-ed together.
    var add_modifiers: int;
    ## The modifiers this style turns off.
    var remove_modifiers: int;

    ## Makes a style. A color left as `Color.Default` is not set, so it
    ## comes from the style beneath; use `fg` or `bg` to set the terminal's
    ## own color over another.
    ##
    ## @param foreground the text color
    ## @param background the background color
    ## @param bold whether to turn bold on
    ## @param dim whether to turn dim on
    ## @param italic whether to turn italic on
    ## @param underline whether to turn underline on
    ## @param reverse whether to turn reversed on
    construct(
        foreground: Color = Color.Default,
        background: Color = Color.Default,
        bold: bool = false,
        dim: bool = false,
        italic: bool = false,
        underline: bool = false,
        reverse: bool = false
    ) {
        if (!(foreground == Color.Default)) {
            this.foreground = Optional<Color>.Value(foreground);
        }
        if (!(background == Color.Default)) {
            this.background = Optional<Color>.Value(background);
        }
        add_modifiers = (bold ? BOLD : 0)
            | (dim ? DIM : 0)
            | (italic ? ITALIC : 0)
            | (underline ? UNDERLINE : 0)
            | (reverse ? REVERSE : 0);
    }

    ## Returns this style with its text color set to `color`, even
    ## `Color.Default`.
    ##
    ## @param color the text color
    ## @returns the new style
    fg(color: Color): Style {
        var style = this;
        style.foreground = Optional<Color>.Value(color);
        return style;
    }

    ## Returns this style with its background set to `color`, even
    ## `Color.Default`.
    ##
    ## @param color the background color
    ## @returns the new style
    bg(color: Color): Style {
        var style = this;
        style.background = Optional<Color>.Value(color);
        return style;
    }

    ## Returns this style with `modifiers` turned on as well.
    ##
    ## @param modifiers the modifiers, such as `BOLD | ITALIC`
    ## @returns the new style
    add_modifier(modifiers: int): Style {
        var style = this;
        style.add_modifiers = add_modifiers | modifiers;
        style.remove_modifiers = remove_modifiers & ~modifiers;
        return style;
    }

    ## Returns this style with `modifiers` turned off.
    ##
    ## @param modifiers the modifiers, such as `BOLD`
    ## @returns the new style
    remove_modifier(modifiers: int): Style {
        var style = this;
        style.add_modifiers = add_modifiers & ~modifiers;
        style.remove_modifiers = remove_modifiers | modifiers;
        return style;
    }

    ## Returns `other` laid over this style: its colors where it sets them,
    ## and its modifiers turned on or off over these.
    ##
    ## @param other the style on top
    ## @returns the combined style
    patch(other: Style): Style {
        var style = this;
        if (other.foreground) {
            style.foreground = other.foreground;
        }
        if (other.background) {
            style.background = other.background;
        }
        style.add_modifiers = (add_modifiers & ~other.remove_modifiers) | other.add_modifiers;
        style.remove_modifiers = (remove_modifiers & ~other.add_modifiers) | other.remove_modifiers;
        return style;
    }

    ## Returns whether this style turns `modifier` on.
    ##
    ## @param modifier one modifier, such as `BOLD`
    ## @returns true when it is on
    has(modifier: int): bool {
        return (add_modifiers & modifier) != 0;
    }

    ## Returns the pepper-term style that draws this one: unset colors are
    ## the terminal's own.
    ##
    ## @returns the terminal style
    to_term(): term.Style {
        return term.Style(
            foreground = foreground.value_or(Color.Default),
            background = background.value_or(Color.Default),
            bold = has(BOLD),
            dim = has(DIM),
            italic = has(ITALIC),
            underline = has(UNDERLINE),
            reverse = has(REVERSE)
        );
    }
}
