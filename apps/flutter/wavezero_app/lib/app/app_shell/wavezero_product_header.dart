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
        borderRadius: 30,
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
                child: const Icon(Icons.graphic_eq_rounded, color: WzColors.textPrimary, size: 21),
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
                      const Flexible(
                        child: Text(
                          'WaveZero',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: WzColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.45,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: stateColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    appMode == WzAppMode.developer
                        ? '$selectedTabLabel • Developer • $engineSummary'
                        : '$selectedTabLabel • $libraryStatus',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WzText.caption,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: libraryColor)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          status == 'Playing' ? 'The music is with you' : status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WzText.caption.copyWith(fontSize: 10.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: WzSpacing.sm),
            WzSculptedIconButton(
              tooltip: 'Settings',
              icon: Icons.tune_rounded,
              size: 44,
              iconSize: 19,
              onPressed: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}
