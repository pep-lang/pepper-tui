## `Scrollbar`: a track along one edge of an area, with a thumb showing
## where the view is; `ScrollbarState` says how long the content is and
## where the view sits.

import "buffer";
import "geometry";
import "style";
import "widget";

## Which edge of its area a `Scrollbar` is drawn along.
export enum ScrollbarOrientation {
    ## Down the right edge.
    VerticalRight,
    ## Down the left edge.
    VerticalLeft,
    ## Along the bottom edge.
    HorizontalBottom,
    ## Along the top edge.
    HorizontalTop,
}

## How long the content a `Scrollbar` scrolls is, and where the view is.
##
## @example
##     import tui;
##
##     var state = tui.ScrollbarState(100);   # 100 rows of content
##     state.position = 40;                   # scrolled to row 40
export struct ScrollbarState {
    ## How long the content is, such as its number of rows; 0 draws no
    ## scrollbar.
    var content_length: int;
    ## The scroll position, such as the first row in view: from 0 to
    ## `content_length` less the rows in view.
    var position: int;
    ## How much of the content shows at once; 0 for the track's length.
    var viewport_content_length: int;

    ## Makes a state.
    ##
    ## @param content_length the number of positions
    ## @param position the current position
    ## @param viewport_content_length how many positions show at once
    construct(content_length: int = 0, position: int = 0, viewport_content_length: int = 0) {
        this.content_length = content_length;
        this.position = position;
        this.viewport_content_length = viewport_content_length;
    }
}

## A scrollbar: arrows at the ends, a track between them, and a thumb as
## long as the share of the content in view, placed by the position.
##
## @example
##     import tui;
##     import [Scrollbar, ScrollbarOrientation, ScrollbarState] from tui;
##
##     var bar = Scrollbar(ScrollbarOrientation.VerticalRight);
##     # in a frame: frame.render_stateful_widget(bar, area, ScrollbarState(100, 40));
export struct Scrollbar {
    ## The edge it is drawn along.
    var orientation: ScrollbarOrientation;
    ## The thumb's symbol.
    var thumb_symbol: String;
    ## The track's symbol.
    var track_symbol: String;
    ## The symbol at the start (top or left); "" for none.
    var begin_symbol: String;
    ## The symbol at the end (bottom or right); "" for none.
    var end_symbol: String;
    ## The style of the thumb.
    var thumb_style: Style;
    ## The style of the track and the end symbols.
    var track_style: Style;

    ## Makes a scrollbar. Empty symbols take the defaults: "║", "▲" and "▼"
    ## for a vertical one, "═", "◄" and "►" for a horizontal one, and "█"
    ## for the thumb.
    ##
    ## @param orientation the edge it is drawn along
    ## @param thumb_symbol the thumb's symbol
    ## @param track_symbol the track's symbol
    ## @param begin_symbol the start symbol
    ## @param end_symbol the end symbol
    ## @param thumb_style the style of the thumb
    ## @param track_style the style of the track
    construct(
        orientation: ScrollbarOrientation = ScrollbarOrientation.VerticalRight,
        thumb_symbol: String = "█",
        track_symbol: String = "",
        begin_symbol: String = "",
        end_symbol: String = "",
        thumb_style: Style = Style(),
        track_style: Style = Style()
    ) {
        this.orientation = orientation;
        var vertical = _is_vertical(orientation);
        this.thumb_symbol = thumb_symbol;
        this.track_symbol = track_symbol.is_empty ? (vertical ? "║" : "═") : track_symbol;
        this.begin_symbol = begin_symbol.is_empty ? (vertical ? "▲" : "◄") : begin_symbol;
        this.end_symbol = end_symbol.is_empty ? (vertical ? "▼" : "►") : end_symbol;
        this.thumb_style = thumb_style;
        this.track_style = track_style;
    }
}

extend Scrollbar with StatefulWidget<ScrollbarState> {
    render(area: Rect, buffer: Buffer, state: ScrollbarState) {
        if (area.is_empty() || state.content_length <= 0) {
            return;
        }
        var vertical = _is_vertical(orientation);
        var length = vertical ? area.height : area.width;
        var x = orientation == ScrollbarOrientation.VerticalRight ? area.right - 1 : area.x;
        var y = orientation == ScrollbarOrientation.HorizontalBottom ? area.bottom - 1 : area.y;
        var ends = length >= 3 ? 1 : 0;
        var track = length - 2 * ends;
        var viewport = state.viewport_content_length > 0 ? state.viewport_content_length : track;
        var content = state.content_length;
        var thumb = viewport >= content ? track : (track * viewport / content).max(1).min(track);
        var range = (content - viewport).max(1);
        var start = (track - thumb) * state.position.max(0).min(range) / range;
        for (var index in 0..length) {
            var symbol = track_symbol;
            var style = track_style;
            if (ends == 1 && index == 0) {
                symbol = begin_symbol;
            } else if (ends == 1 && index == length - 1) {
                symbol = end_symbol;
            } else if (index - ends >= start && index - ends < start + thumb) {
                symbol = thumb_symbol;
                style = thumb_style;
            }
            if (vertical) {
                buffer.set_string(x, area.y + index, symbol, style);
            } else {
                buffer.set_string(area.x + index, y, symbol, style);
            }
        }
    }
}

_is_vertical(orientation: ScrollbarOrientation): bool {
    return orientation == ScrollbarOrientation.VerticalRight || orientation == ScrollbarOrientation.VerticalLeft;
}
