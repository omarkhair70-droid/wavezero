import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/web/web_library_service.dart';

void main() {
  test('web history keeps the newest visit for each URL', () {
    var state = const WzWebLibraryState();
    state = state.recordVisit(
      url: 'https://example.com/a',
      title: 'First',
      visitedAtMs: 10,
    );
    state = state.recordVisit(
      url: 'https://example.com/b',
      title: 'Second',
      visitedAtMs: 20,
    );
    state = state.recordVisit(
      url: 'https://example.com/a',
      title: 'First again',
      visitedAtMs: 30,
    );

    expect(state.history, hasLength(2));
    expect(state.history.first.url, 'https://example.com/a');
    expect(state.history.first.title, 'First again');
    expect(state.history.last.url, 'https://example.com/b');
  });

  test('bookmark toggle preserves history and removes on second toggle', () {
    var state = const WzWebLibraryState().recordVisit(
      url: 'https://music.example/song',
      title: 'Song',
      visitedAtMs: 5,
    );
    state = state.toggleBookmark(
      url: 'https://music.example/song',
      title: 'Song',
      updatedAtMs: 10,
    );
    expect(state.isBookmarked('https://music.example/song'), isTrue);
    expect(state.history, hasLength(1));

    state = state.toggleBookmark(
      url: 'https://music.example/song',
      title: 'Song',
      updatedAtMs: 20,
    );
    expect(state.isBookmarked('https://music.example/song'), isFalse);
    expect(state.history, hasLength(1));
  });

  test('web library JSON round trip rejects non-http records', () {
    const source = '''
    {
      "bookmarks": [
        {"url":"https://example.com","title":"Example","updatedAtMs":20},
        {"url":"file:///tmp/test","title":"Bad","updatedAtMs":30}
      ],
      "history": [
        {"url":"https://example.com/a","title":"A","updatedAtMs":10}
      ]
    }
    ''';

    final state = wzWebLibraryStateFromJson(source);
    expect(state.bookmarks, hasLength(1));
    expect(state.history, hasLength(1));

    final decoded = wzWebLibraryStateFromJson(wzWebLibraryStateToJson(state));
    expect(decoded.bookmarks.single.url, 'https://example.com');
    expect(decoded.history.single.url, 'https://example.com/a');
  });
}
