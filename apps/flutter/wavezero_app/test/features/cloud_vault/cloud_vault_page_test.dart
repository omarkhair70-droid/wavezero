import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wavezero_app/features/cloud_vault/cloud_vault_page.dart';

void main() {
  testWidgets('empty Cloud Vault keeps the privacy-first foundation copy', (tester) async {
    final title = TextEditingController();
    final artist = TextEditingController();
    final url = TextEditingController();
    final provider = TextEditingController();
    addTearDown(title.dispose);
    addTearDown(artist.dispose);
    addTearDown(url.dispose);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: WzCloudVaultPage(
          tracks: const [],
          developerMode: false,
          titleController: title,
          artistController: artist,
          playableUrlController: url,
          providerLabelController: provider,
          onAddDeveloperTrack: () async {},
          onPlay: (_) {},
          onAddToQueue: (_) {},
          onRemove: (_) {},
          onClearAll: null,
        ),
      ),
    );
    expect(find.text('Cloud Vault'), findsWidgets);
    expect(find.text('Privacy-first foundation'), findsOneWidget);
    expect(find.textContaining('does not upload your cloud files'), findsOneWidget);
    expect(find.textContaining('No cloud music connected yet.'), findsOneWidget);
  });
}
