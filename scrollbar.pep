## `Scrollbar`: a track along one edge of an area, with a thumb showing
## where the view is; `ScrollbarState` says how long the content is and
## where the view sits.

import term;
import "buffer";
import "events";
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
    # Where the last draw put the track (the cells between the arrows) and
    # the thumb, counted from the track's start, for `handle_mouse`; and
    # where in the thumb a drag holds it, -1 when no drag is on.
    var _track: Rect;
    var _vertical: bool;
    var _thumb_start: int;
    var _thumb_length: int;
    var _grab = -1;

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

    ## Acts on a mouse event: the wheel over `area` scrolls by one, a left
    ## click on the track of the `Scrollbar` last drawn with this state
    ## moves the thumb there, and dragging the thumb moves it along. The
    ## position stays from 0 to `content_length` less the viewport.
    ##
    ## The state can scroll content with no scrollbar drawn, such as a
    ## `Paragraph` drawn with `scroll = state.position`; set
    ## `viewport_content_length` to the rows it shows.
    ##
    ## @param event the mouse event, as `Event.Mouse` gives it
    ## @param area where the wheel scrolls, such as the scrolled widget's
    ##   area from `Terminal.area_of`
    ## @returns true when it acted on the event
    handle_mouse(event: term.MouseEvent, area: Rect): bool {
        var column = event.column as int;
        var row = event.row as int;
        var cell = _vertical ? row - _track.y : column - _track.x;
        if (_grab >= 0 && event.kind == term.MouseKind.Drag) {
            _move_thumb(cell - _grab);
            return true;
        }
        if (_grab >= 0 && event.kind == term.MouseKind.Up) {
            _grab = -1;
            return true;
        }
        if (_is_left_click(event) && _track.contains(column, row)) {
            var on_thumb = cell >= _thumb_start && cell < _thumb_start + _thumb_length;
            _grab = on_thumb ? cell - _thumb_start : _thumb_length / 2;
            _move_thumb(cell - _grab);
            return true;
        }
        if (!area.contains(column, row)) {
            return false;
        }
        if (event.kind == term.MouseKind.ScrollDown || event.kind == term.MouseKind.ScrollRight) {
            position = (position + 1).min(_last_position()).max(0);
            return true;
        }
        if (event.kind == term.MouseKind.ScrollUp || event.kind == term.MouseKind.ScrollLeft) {
            position = (position - 1).min(_last_position()).max(0);
            return true;
        }
        return false;
    }

    _viewport(): int {
        return viewport_content_length > 0 ? viewport_content_length : (_vertical ? _track.height : _track.width);
    }

    _last_position(): int {
        return (content_length - _viewport()).max(0);
    }

    # Sets the position that draws the thumb from `start`, the inverse of
    # where `render` puts it, rounded to the nearest.
    _move_thumb(start: int) {
        var free = (_vertical ? _track.height : _track.width) - _thumb_length;
        if (free <= 0) {
            return;
        }
        var range = _last_position();
        position = (start.max(0).min(free) * range + free / 2) / free;
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
        var vertical = _is_vertical(orientation);
        state._vertical = vertical;
        state._track = Rect();
        if (area.is_empty() || state.content_length <= 0) {
            return;
        }
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
        state._track = vertical ? Rect(x, area.y + ends, 1, track) : Rect(area.x + ends, y, track, 1);
        state._thumb_start = start;
        state._thumb_length = thumb;
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
