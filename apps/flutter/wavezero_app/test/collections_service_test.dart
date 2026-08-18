import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/features/collections/collections_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  WzCollection collection(String id, String name) => WzCollection(
    id: id,
    name: name,
    type: WzCollectionType.user,
    createdAtMs: 1,
    updatedAtMs: 1,
  );

  test('missing persistence always restores Liked Tracks', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = CollectionsService(prefs: prefs);

    final restored = await service.load();

    expect(restored, hasLength(1));
    expect(restored.single.id, likedTracksCollectionId);
    expect(restored.single.name, 'Liked Tracks');
  });

  test('unawaited-style saves preserve call order and latest state wins', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = CollectionsService(prefs: prefs);

    final first = service.save([
      WzCollection.liked(nowMs: 1),
      collection('one', 'One'),
    ]);
    final second = service.save([
      WzCollection.liked(nowMs: 1),
      collection('two', 'Two'),
    ]);
    final latest = service.save([
      WzCollection.liked(nowMs: 1),
      collection('three', 'Three'),
    ]);

    await Future.wait([first, second, latest]);
    final restored = await service.load();

    expect(restored.map((item) => item.id).toList(), [
      likedTracksCollectionId,
      'three',
    ]);
  });

  test('save snapshots caller list before queued persistence runs', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = CollectionsService(prefs: prefs);
    final source = <WzCollection>[
      WzCollection.liked(nowMs: 1),
      collection('kept', 'Kept'),
    ];

    final write = service.save(source);
    source
      ..clear()
      ..add(collection('mutated', 'Mutated'));
    await write;

    final restored = await service.load();
    expect(restored.any((item) => item.id == 'kept'), isTrue);
    expect(restored.any((item) => item.id == 'mutated'), isFalse);
  });
}
