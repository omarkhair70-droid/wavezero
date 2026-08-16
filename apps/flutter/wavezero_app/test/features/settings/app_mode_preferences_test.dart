import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wavezero_app/app/navigation/wavezero_navigation.dart';
import 'package:wavezero_app/features/settings/app_mode_preferences.dart';

void main() {
  const store = WzAppModePreferences();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to consumer mode', () async {
    expect(await store.load(allowDeveloper: true), WzAppMode.consumer);
  });

  test('restores developer mode only when developer entry is allowed', () async {
    SharedPreferences.setMockInitialValues({
      WzAppModePreferences.preferenceKey: WzAppMode.developer.name,
    });
    expect(await store.load(allowDeveloper: true), WzAppMode.developer);
    expect(await store.load(allowDeveloper: false), WzAppMode.consumer);
  });

  test('saves the persisted enum name', () async {
    await store.save(WzAppMode.developer);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(WzAppModePreferences.preferenceKey),
      WzAppMode.developer.name,
    );
  });
}
