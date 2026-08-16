import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';
import '../navigation/wavezero_navigation.dart';

class WaveZeroBottomShell extends StatelessWidget {
  const WaveZeroBottomShell({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.accent,
    this.miniPlayer,
  });

  final List<WzShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Color accent;
  final Widget? miniPlayer;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (miniPlayer != null) ...[
              miniPlayer!,
              const SizedBox(height: 8),
            ],
            WzGlassCard(
              borderRadius: 32,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: Row(
                children: List.generate(destinations.length, (index) {
                  final destination = destinations[index];
                  final selected = currentIndex == index;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _PorcelainDestination(
                        icon: destination.icon,
                        label: destination.label,
                        selected: selected,
                        accent: accent,
                        onTap: () => onDestinationSelected(index),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      );
}

class _PorcelainDestination extends StatelessWidget {
  const _PorcelainDestination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => WzPressableSurface(
        onTap: onTap,
        radius: 24,
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, accent.withValues(alpha: 0.13)],
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: selected ? Border.all(color: accent.withValues(alpha: 0.18)) : null,
          boxShadow: selected ? WzSurface.softShadows : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: selected ? 22 : 20, color: selected ? accent : WzColors.textMuted),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: WzText.caption.copyWith(
                fontSize: 9.5,
                color: selected ? WzColors.textPrimary : WzColors.textSubtle,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}
