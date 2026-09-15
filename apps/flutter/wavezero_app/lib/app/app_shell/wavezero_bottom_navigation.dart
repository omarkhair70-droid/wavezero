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
        minimum: const EdgeInsets.fromLTRB(14, 2, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (miniPlayer != null) ...[
              miniPlayer!,
              const SizedBox(height: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFAFFFFFF), Color(0xF1F7FAFC)],
                ),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: const Color(0xE6FFFFFF), width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Color(0x120B2438), blurRadius: 28, offset: Offset(0, 12)),
                  BoxShadow(color: Color(0xD9FFFFFF), blurRadius: 9, offset: Offset(-3, -4)),
                ],
              ),
              child: Row(
                children: List.generate(destinations.length, (index) {
                  final destination = destinations[index];
                  final selected = currentIndex == index;
                  return Expanded(
                    child: _PorcelainDestination(
                      icon: destination.icon,
                      label: destination.label,
                      selected: selected,
                      accent: accent,
                      onTap: () => onDestinationSelected(index),
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
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: WzPressableSurface(
            onTap: onTap,
            radius: 28,
            decoration: selected
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, accent.withValues(alpha: 0.14)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white, width: 1.1),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.11), blurRadius: 20, offset: const Offset(0, 8)),
                      const BoxShadow(color: Color(0xBFFFFFFF), blurRadius: 8, offset: Offset(-2, -3)),
                    ],
                  )
                : BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(28),
                  ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: AnimatedSize(
              duration: WzMotion.normal,
              curve: WzMotion.curve,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: WzMotion.normal,
                    curve: WzMotion.curve,
                    width: selected ? 34 : 28,
                    height: selected ? 34 : 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? Colors.white.withValues(alpha: 0.84) : Colors.transparent,
                      boxShadow: selected ? WzSurface.softShadows : const [],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: selected ? 20 : 19,
                      color: selected ? WzColors.textPrimary : WzColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: WzText.caption.copyWith(
                      fontSize: 10,
                      color: selected ? WzColors.textPrimary : WzColors.textSubtle,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
