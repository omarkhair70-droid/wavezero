from pathlib import Path

repo = Path(__file__).resolve().parents[2]
path = repo / 'apps/flutter/wavezero_app/lib/features/playback/consumer_player.dart'
text = path.read_text()

old_init = '''    _ticker = createTicker((elapsed) {
      _tickerElapsed = elapsed;
      if (mounted && widget.isPlaying && _dragValue == null) setState(() {});
    })..start();
'''
new_init = '''    _ticker = createTicker((elapsed) {
      _tickerElapsed = elapsed;
      if (mounted && widget.isPlaying && _dragValue == null) setState(() {});
    });
    if (widget.isPlaying) _ticker.start();
'''
if text.count(old_init) != 1:
    raise SystemExit(f'smooth ticker init: expected one match, got {text.count(old_init)}')
text = text.replace(old_init, new_init, 1)

old_update = '''    if (oldWidget.positionMs != widget.positionMs ||
        oldWidget.durationMs != widget.durationMs ||
        oldWidget.isPlaying != widget.isPlaying) {
      _anchorPositionMs = widget.positionMs;
      _anchorElapsed = _tickerElapsed;
    }
'''
new_update = '''    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _tickerElapsed = Duration.zero;
        _anchorElapsed = Duration.zero;
        if (!_ticker.isActive) _ticker.start();
      } else if (_ticker.isActive) {
        _ticker.stop();
      }
    }
    if (oldWidget.positionMs != widget.positionMs ||
        oldWidget.durationMs != widget.durationMs ||
        oldWidget.isPlaying != widget.isPlaying) {
      _anchorPositionMs = widget.positionMs;
      _anchorElapsed = _tickerElapsed;
    }
'''
if text.count(old_update) != 1:
    raise SystemExit(f'smooth ticker update: expected one match, got {text.count(old_update)}')
text = text.replace(old_update, new_update, 1)
path.write_text(text)
