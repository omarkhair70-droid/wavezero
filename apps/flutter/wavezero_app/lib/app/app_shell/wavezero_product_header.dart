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
  Widget build(BuildContext context) {
    if (appMode == WzAppMode.developer) return _buildDeveloperHeader();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onLongPress: onLogoLongPress,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: themeConfig.accentGradient,
                border: Border.all(color: Colors.white),
                boxShadow: WzSurface.softShadows,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.graphic_eq_rounded, color: WzColors.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: WzSpacing.sm),
          const Expanded(
            child: Text(
              'WaveZero',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: WzColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.55,
              ),
            ),
          ),
          WzSculptedIconButton(
            tooltip: 'Settings',
            icon: Icons.tune_rounded,
            size: 42,
            iconSize: 18,
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperHeader() {
    final stateColor = status == 'Error'
        ? WzColors.danger
        : status == 'Playing'
            ? WzColors.success
            : WzColors.accent;
    final libraryColor = libraryStatusWarning
        ? WzColors.warning
        : libraryStatusActive
            ? WzColors.success
            : WzColors.textSubtle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: WzGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        gradient: themeConfig.shellGradient,
        child: Row(
          children: [
            GestureDetector(
              onLongPress: onLogoLongPress,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: themeConfig.accentGradient,
                  border: Border.all(color: Colors.white),
                  boxShadow: WzSurface.softShadows,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.engineering_rounded, color: WzColors.textPrimary, size: 20),
              ),
            ),
            const SizedBox(width: WzSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('WaveZero Developer', style: WzText.sectionTitle),
                      const SizedBox(width: 8),
                      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: stateColor)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('$selectedTabLabel • $engineSummary', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: libraryColor)),
                      const SizedBox(width: 6),
                      Flexible(child: Text('$libraryStatus • $status', maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption)),
                    ],
                  ),
                ],
              ),
            ),
            WzSculptedIconButton(
              tooltip: 'Settings',
              icon: Icons.tune_rounded,
              size: 42,
              iconSize: 18,
              onPressed: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}
