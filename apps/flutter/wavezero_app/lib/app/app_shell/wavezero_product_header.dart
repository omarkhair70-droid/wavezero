import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import '../navigation/wavezero_navigation.dart';
import '../theme/wavezero_theme.dart';

class WaveZeroProductHeader extends StatelessWidget {
  const WaveZeroProductHeader({
    super.key,
    required this.selectedTabLabel,
    required this.status,
    required this.engineSummary,
    required this.libraryStatus,
    required this.libraryStatusActive,
    required this.libraryStatusWarning,
    required this.appMode,
    required this.themeConfig,
    required this.onLogoLongPress,
    required this.onOpenSettings,
  });

  final String selectedTabLabel;
  final String status;
  final String engineSummary;
  final String libraryStatus;
  final bool libraryStatusActive;
  final bool libraryStatusWarning;
  final WzAppMode appMode;
  final WzThemeConfig themeConfig;
  final VoidCallback onLogoLongPress;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: WzPanel(
          padding: const EdgeInsets.symmetric(horizontal: WzSpacing.sm, vertical: WzSpacing.xs),
          gradient: themeConfig.shellGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onLongPress: onLogoLongPress,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: themeConfig.accentGradient,
                        borderRadius: BorderRadius.circular(WzRadius.md),
                      ),
                      child: const Icon(Icons.graphic_eq, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: WzSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WaveZero',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                        ),
                        const SizedBox(height: WzSpacing.xxs),
                        Text(
                          appMode == WzAppMode.developer
                              ? '$selectedTabLabel • Developer mode • $engineSummary'
                              : '$selectedTabLabel • $libraryStatus',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WzText.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: onOpenSettings,
                    icon: Icon(Icons.settings, color: themeConfig.accent),
                  ),
                ],
              ),
              const SizedBox(height: WzSpacing.xs),
              Wrap(
                spacing: WzSpacing.xs,
                runSpacing: WzSpacing.xs,
                children: [
                  WzStatusPill(
                    label: status,
                    active: status == 'Playing',
                    warning: status == 'Error',
                    icon: Icons.radio_button_checked,
                  ),
                  WzStatusPill(
                    label: libraryStatus,
                    active: libraryStatusActive,
                    warning: libraryStatusWarning,
                    icon: libraryStatus == 'Offline Ready'
                        ? Icons.offline_pin
                        : libraryStatus == 'Device music ready'
                            ? Icons.phone_android
                            : Icons.library_music,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
