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
        minimum: const EdgeInsets.fromLTRB(14, 2, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (miniPlayer != null) ...[
              miniPlayer!,
              const SizedBox(height: 10),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFAFFFFFF), Color(0xF1F7FAFC)],
                ),
                borderRadius: BorderRadius.circular(38),
                border: Border.all(color: const Color(0xE6FFFFFF), width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Color(0x120B2438), blurRadius: 32, offset: Offset(0, 14)),
                  BoxShadow(color: Color(0xD9FFFFFF), blurRadius: 10, offset: Offset(-3, -4)),
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
            radius: 30,
            decoration: selected
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, accent.withValues(alpha: 0.14)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white, width: 1.1),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10)),
                      const BoxShadow(color: Color(0xBFFFFFFF), blurRadius: 10, offset: Offset(-2, -3)),
                    ],
                  )
                : BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(30),
                  ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
            child: AnimatedSize(
              duration: WzMotion.normal,
              curve: WzMotion.curve,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: WzMotion.normal,
                    curve: WzMotion.curve,
                    width: selected ? 38 : 30,
                    height: selected ? 38 : 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? Colors.white.withValues(alpha: 0.84) : Colors.transparent,
                      boxShadow: selected ? WzSurface.softShadows : const [],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: selected ? 22 : 20,
                      color: selected ? WzColors.textPrimary : WzColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
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
