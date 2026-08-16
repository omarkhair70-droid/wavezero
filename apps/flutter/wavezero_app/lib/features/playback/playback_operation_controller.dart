import 'player_operation_state.dart';

class WzPlaybackOperationController {
  PlayerOperation _current = PlayerOperation.idle;

  PlayerOperation get current => _current;

  bool tryBegin(PlayerOperation operation) {
    if (_current != PlayerOperation.idle) return false;
    _current = operation;
    return true;
  }

  void end() {
    _current = PlayerOperation.idle;
  }
}
