## The widget traits: a `Widget` draws itself into a buffer, and a
## `StatefulWidget` draws with state the app keeps between frames, such as
## a list's selection.

import "buffer";
import "geometry";

## Something that draws itself into an area of a buffer. Every widget of
## this package is one, and an app writes its own the same way.
##
## @example
##     import tui;
##     import [Buffer, Rect, Style, Widget] from tui;
##
##     struct Hello {}
##
##     extend Hello with Widget {
##         render(area: Rect, buffer: Buffer) {
##             buffer.set_string(area.x, area.y, "hello", Style(), area.width);
##         }
##     }
export trait Widget {
    ## Draws the widget into `area` of `buffer`.
    ##
    ## @param area where to draw; the widget draws nothing outside it
    ## @param buffer the buffer to draw into
    render(area: Rect, buffer: Buffer);
}

## A widget that draws with state the app keeps from frame to frame: the
## widget reads it, and may change it (a list scrolls its offset to keep
## the selection in view).
##
## @typeParam TState the state's type, such as `ListState`
export trait StatefulWidget<TState> {
    ## Draws the widget into `area` of `buffer` with `state`.
    ##
    ## @param area where to draw
    ## @param buffer the buffer to draw into
    ## @param state the state, which the widget may change
    render(area: Rect, buffer: Buffer, state: TState);
}
