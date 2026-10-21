## Leaving the full-screen state however the program ends, private to the
## module: at exit, and on the signals that end it, a panic's SIGABRT
## included. pepper-term restores raw mode on these paths; this file adds the
## alternate screen and the cursor, and restores raw mode too where its
## handler takes the place of pepper-term's.

import async;
import term;

[Target(!OS(Windows))]
extern long write(int fd, void* buffer, ulong size);
[Target(OS(Windows))]
extern int _write(int fd, void* buffer, uint size);
extern void* signal(int number, void* handler);
extern int atexit(void* function);
[Target(!OS(Windows))]
extern int raise(int number);

# The sequences that set up the screen, and that put it back.
const _TUI_ENTER = "\x1B[?1049h\x1B[?25l\x1B[2J";
const _TUI_LEAVE = "\x1B[0m\x1B[?25h\x1B[?1049l";

# Whether the screen is set up, so leaving it knows to act.
const _tui_active = async.Atomic<bool>(false);
const _tui_hooks = async.Once();

_tui_enter() {
    _tui_active.store(true);
    _tui_write(_TUI_ENTER);
}

# Async-signal-safe: a signal handler calls it.
_tui_leave() {
    if (_tui_active.exchange(false)) {
        _tui_write(_TUI_LEAVE);
    }
}

[Target(!OS(Windows))]
_tui_write(sequence: String) {
    write(1, sequence.c_str(), sequence.size);
}

[Target(OS(Windows))]
_tui_write(sequence: String) {
    _write(1, sequence.c_str(), sequence.size as uint);
}

# Installed before pepper-term turns raw mode on, so where its handler
# would go this one stays, and restores raw mode itself.
_tui_install_hooks() {
    _tui_hooks.call(_tui_hook);
}

[Target(!OS(Windows))]
_tui_hook() {
    var at_exit: extern () => void = _tui_leave;
    atexit(at_exit);
    var handler: extern (int) => void = _tui_on_signal;
    # SIGHUP, SIGINT, SIGQUIT, SIGABRT, SIGTERM.
    for (var number in [1, 2, 3, 6, 15]) {
        var previous = signal(number, handler);
        if (previous != __null) {
            signal(number, previous);
        }
    }
}

# A panic has printed its message by now, on the alternate screen that this
# leaves; nothing can run sooner (pep-lang/pepper#83).
[Target(!OS(Windows))]
_tui_on_signal(number: int) {
    _tui_leave();
    term.restore();
    signal(number, __null);
    raise(number);
}

[Target(OS(Windows))]
_tui_hook() {
    var at_exit: extern () => void = _tui_leave;
    atexit(at_exit);
    var handler: extern (int) => void = _tui_on_abort;
    var previous = signal(22, handler);  # SIGABRT
    if (previous != __null) {
        signal(22, previous);
    }
}

[Target(OS(Windows))]
_tui_on_abort(number: int) {
    _tui_leave();
    term.restore();
}
