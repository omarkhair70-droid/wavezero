from pathlib import Path

root = Path.cwd()
app_path = root / 'apps/flutter/wavezero_app/lib/app/wavezero_app.dart'
history_path = root / 'apps/flutter/wavezero_app/lib/features/home/home_curated_history.dart'
workflow_path = root / '.github/workflows/_oneoff_wire_consumer_home.yml'
script_path = root / 'tools/_oneoff_wire_consumer_home.py'

app = app_path.read_text(encoding='utf-8')
if "../features/home/consumer_home.dart" not in app:
    app = app.replace("import '../features/home/home_sections.dart';\n", "import '../features/home/home_sections.dart';\nimport '../features/home/consumer_home.dart';\n", 1)

start = app.find('          WzHomeHero(themeConfig: widget.themeConfig),')
end = app.find('          WzHomeCuratedDemoSection(', start)
if start < 0 or end < 0:
    raise SystemExit('Home consumer block markers not found')
new_home = '''          WzConsumerHomeHero(themeConfig: widget.themeConfig),
          const SizedBox(height: WzSpacing.xl),
          WzConsumerNowCard(
            metrics: _metrics,
            manifest: _manifest,
            progressValue: progress,
            onOpen: _showPremiumPlayerSheet,
            onPlayPause: _playPause,
            controlsDisabled: _playerDisabled,
          ),
          const SizedBox(height: WzSpacing.xl),
'''
app = app[:start] + new_home + app[end:]
app_path.write_text(app, encoding='utf-8')

history = history_path.read_text(encoding='utf-8')
old = '''                  onSelected: (value) {
                    switch (value) {
                      case 'queue':
                        onAddToQueue();
                      case 'collection':
                        onAddToCollection();
                      case 'remove':
                        onRemove();
                    }
                  },'''
new = '''                  onSelected: (value) {
                    if (value == 'queue') onAddToQueue();
                    if (value == 'collection') onAddToCollection();
                    if (value == 'remove') onRemove();
                  },'''
if old not in history:
    raise SystemExit('history popup callback marker not found')
history = history.replace(old, new, 1)
history_path.write_text(history, encoding='utf-8')

for path in (workflow_path, script_path):
    if path.exists():
        path.unlink()
