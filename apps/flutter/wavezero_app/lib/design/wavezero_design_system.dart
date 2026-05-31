import 'package:flutter/material.dart';

/// WaveZero Design System v1.
///
/// This is intentionally additive: existing private tokens can mirror these
/// values while product pages gradually move onto the shared system.
class WzColors {
  const WzColors._();

  static const Color canvas = Color(0xFF060810);
  static const Color canvasTop = Color(0xFF0C1020);
  static const Color surface = Color(0xFF101521);
  static const Color surfaceElevated = Color(0xFF151B2A);
  static const Color surfaceMuted = Color(0xFF0B0F19);
  static const Color border = Color(0xFF252E43);
  static const Color borderSoft = Color(0xFF1C2435);
  static const Color accent = Color(0xFF9A8CFF);
  static const Color accentAlt = Color(0xFF36D7FF);
  static const Color accentSoft = Color(0x1F9A8CFF);
  static const Color success = Color(0xFF38D996);
  static const Color successSoft = Color(0x1838D996);
  static const Color warning = Color(0xFFFFC46B);
  static const Color warningSoft = Color(0x1AFFC46B);
  static const Color danger = Color(0xFFFF6B8A);
  static const Color dangerSoft = Color(0x1AFF6B8A);
  static const Color textPrimary = Color(0xFFF3F5FB);
  static const Color textMuted = Color(0xFFA4ADC1);
  static const Color textSubtle = Color(0xFF7F899F);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2140), Color(0xFF0B0F19), Color(0xFF141026)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentAlt],
  );
}

class WzSpacing {
  const WzSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class WzRadius {
  const WzRadius._();

  static const double sm = 14;
  static const double md = 18;
  static const double lg = 26;
  static const double xl = 32;
}

class WzText {
  const WzText._();

  static const TextStyle display = TextStyle(
    color: WzColors.textPrimary,
    fontSize: 38,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.2,
  );
  static const TextStyle pageTitle = TextStyle(
    color: WzColors.textPrimary,
    fontSize: 26,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.7,
  );
  static const TextStyle title = TextStyle(
    color: WzColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
  );
  static const TextStyle sectionTitle = TextStyle(
    color: WzColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w900,
  );
  static const TextStyle body = TextStyle(color: WzColors.textMuted, fontSize: 13, height: 1.35);
  static const TextStyle caption = TextStyle(color: WzColors.textSubtle, fontSize: 12, height: 1.3);
  static const TextStyle eyebrow = TextStyle(
    color: WzColors.accent,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
  );
}

class WzMotion {
  const WzMotion._();

  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 240);
}

class WzSurface {
  const WzSurface._();

  static BoxDecoration panel({bool elevated = true}) => BoxDecoration(
        color: elevated ? WzColors.surface : WzColors.surfaceMuted,
        borderRadius: BorderRadius.circular(WzRadius.xl),
        border: Border.all(color: WzColors.border),
        boxShadow: elevated ? shadows : null,
      );

  static const List<BoxShadow> shadows = [
    BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 18)),
  ];
}

class WzPageScaffold extends StatelessWidget {
  const WzPageScaffold({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(22, 20, 22, 28),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class WzPageHeader extends StatelessWidget {
  const WzPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: WzColors.accent),
            const SizedBox(width: WzSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: WzText.pageTitle),
                const SizedBox(height: WzSpacing.xxs),
                Text(subtitle, style: WzText.body),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: WzSpacing.sm),
            trailing!,
          ],
        ],
      );
}

class WzSectionHeader extends StatelessWidget {
  const WzSectionHeader({super.key, required this.title, required this.subtitle, this.icon});

  final String title;
  final String subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: WzSpacing.sm),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: WzColors.accent, size: 18),
              const SizedBox(width: WzSpacing.xs),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: WzText.sectionTitle),
                  const SizedBox(height: WzSpacing.xxs),
                  Text(subtitle, style: WzText.caption),
                ],
              ),
            ),
          ],
        ),
      );
}

class WzPanel extends StatelessWidget {
  const WzPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.gradient});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: WzSurface.panel().copyWith(gradient: gradient),
        child: Padding(padding: padding, child: child),
      );
}

class WzGlassCard extends StatelessWidget {
  const WzGlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.gradient});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => WzPanel(padding: padding, gradient: gradient, child: child);
}

class WzStatusPill extends StatelessWidget {
  const WzStatusPill({super.key, required this.label, this.active = false, this.warning = false, this.icon});

  final String label;
  final bool active;
  final bool warning;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = warning ? WzColors.warning : active ? WzColors.success : WzColors.accent;
    final fill = warning ? WzColors.warningSoft : active ? WzColors.successSoft : WzColors.accentSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(WzRadius.sm),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
          ],
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption.copyWith(color: WzColors.textPrimary)),
        ],
      ),
    );
  }
}

class WzPrimaryAction extends StatelessWidget {
  const WzPrimaryAction({super.key, required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
}

class WzMiniMetric extends StatelessWidget {
  const WzMiniMetric({super.key, required this.label, required this.value, this.active = false, this.icon});

  final String label;
  final String value;
  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 132, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? WzColors.successSoft : WzColors.surfaceElevated,
          borderRadius: BorderRadius.circular(WzRadius.md),
          border: Border.all(color: active ? WzColors.success.withOpacity(0.45) : WzColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: active ? WzColors.success : WzColors.accent),
                  const SizedBox(width: 6),
                ],
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: WzText.caption)),
              ],
            ),
            const SizedBox(height: WzSpacing.xxs),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}
