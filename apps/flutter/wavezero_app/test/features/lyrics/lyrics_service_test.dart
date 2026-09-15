import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/features/lyrics/lyrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('save and load keep lyrics attached to stable track id', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = WzLyricsService(prefs: prefs);

    await service.save(trackId: 'device-42', rawText: 'hello\nworld');
    final restored = await service.loadAll();

    expect(restored.keys, contains('device-42'));
    expect(restored['device-42']?.rawText, 'hello\nworld');
  });

  test('blank save removes an existing document', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = WzLyricsService(prefs: prefs);

    await service.save(trackId: 'track-a', rawText: 'lyrics');
    await service.save(trackId: 'track-a', rawText: '   ');

    expect((await service.loadAll()).containsKey('track-a'), isFalse);
  });

  test('queued mutations preserve the latest local edit', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = WzLyricsService(prefs: prefs);

    final first = service.save(trackId: 'track-a', rawText: 'first');
    final second = service.save(trackId: 'track-a', rawText: 'second');
    final latest = service.save(trackId: 'track-a', rawText: 'latest');
    await Future.wait([first, second, latest]);

    expect((await service.loadAll())['track-a']?.rawText, 'latest');
  });
}
