import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/playback/playback_operation_controller.dart';
import 'package:wavezero_app/features/playback/player_operation_state.dart';

void main() {
  test('starts idle and admits the first operation', () {
    final controller = WzPlaybackOperationController();

    expect(controller.current, PlayerOperation.idle);
    expect(controller.tryBegin(PlayerOperation.loadingTrack), isTrue);
    expect(controller.current, PlayerOperation.loadingTrack);
  });

  test('rejects nested operations without replacing the active operation', () {
    final controller = WzPlaybackOperationController();
    controller.tryBegin(PlayerOperation.loadingTrack);

    expect(controller.tryBegin(PlayerOperation.seeking), isFalse);
    expect(controller.current, PlayerOperation.loadingTrack);
  });

  test('end returns to idle and allows the next operation', () {
    final controller = WzPlaybackOperationController();
    controller.tryBegin(PlayerOperation.playbackCommand);

    controller.end();

    expect(controller.current, PlayerOperation.idle);
    expect(controller.tryBegin(PlayerOperation.seeking), isTrue);
    expect(controller.current, PlayerOperation.seeking);
  });
}
