import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// WaveZero's Porcelain design language.
///
/// The product should feel light, close and physical rather than dark or
/// conventionally "premium": milk-white surfaces, restrained translucency,
/// soft depth and small tactile movement on interaction.
class WzColors {
  const WzColors._();

  static const Color canvas = Color(0xFFF7F9FB);
  static const Color canvasTop = Color(0xFFFFFFFF);
  static const Color surface = Color(0xF7FFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfacePremium = Color(0xFFF9FBFD);
  static const Color surfaceMuted = Color(0xFFF0F4F7);
  static const Color porcelain = Color(0xFFFDFEFE);
  static const Color porcelainWarm = Color(0xFFFFFBF6);
  static const Color porcelainBlue = Color(0xFFF2F8FD);
  static const Color border = Color(0xFFDCE4EA);
  static const Color borderSoft = Color(0xFFE8EEF3);
  static const Color accent = Color(0xFF6F9FCA);
  static const Color accentAlt = Color(0xFFA9CBE7);
  static const Color accentSoft = Color(0x1F6F9FCA);
  static const Color success = Color(0xFF5D987F);
  static const Color successSoft = Color(0x185D987F);
  static const Color warning = Color(0xFFB48756);
  static const Color warningSoft = Color(0x1AB48756);
  static const Color danger = Color(0xFFC76E78);
  static const Color dangerSoft = Color(0x1AC76E78);
  static const Color textPrimary = Color(0xFF17222C);
  static const Color textMuted = Color(0xFF697986);
  static const Color textSubtle = Color(0xFF8B99A5);

  static const LinearGradient canvasGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF7FAFC), Color(0xFFF1F7FB)],
    stops: [0.0, 0.56, 1.0],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFD), Color(0xFFEFF7FC)],
    stops: [0.0, 0.58, 1.0],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF6), Color(0xFFF7F5F2)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEAF4FB), Color(0xFFCFE4F3), Color(0xFFF9FCFE)],
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
  static const double md = 19;
  static const double lg = 27;
  static const double xl = 36;
  static const double sculpted = 44;
}

class WzText {
  const WzText._();

  static const TextStyle display = TextStyle(
    color: WzColors.textPrimary,
    fontSize: 38,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.25,
  );
  static const TextStyle pageTitle = TextStyle(
    color: WzColors.textPrimary,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.75,
  );
  static const TextStyle title = TextStyle(
    color: WzColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.35,
  );
  static const TextStyle sectionTitle = TextStyle(
    color: WzColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.15,
  );
  static const TextStyle body = TextStyle(color: WzColors.textMuted, fontSize: 13, height: 1.42);
  static const TextStyle caption = TextStyle(color: WzColors.textSubtle, fontSize: 12, height: 1.35);
  static const TextStyle eyebrow = TextStyle(
    color: WzColors.accent,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.55,
  );
}

class WzMotion {
  const WzMotion._();

  static const Duration fast = Duration(milliseconds: 105);
  static const Duration normal = Duration(milliseconds: 185);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve pressCurve = Curves.easeOutQuart;

  static const Duration quick = fast;
  static const Duration standard = normal;
}

class WzSurface {
  const WzSurface._();

  static BoxDecoration panel({bool elevated = true}) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xF2F8FBFD)],
        ),
        borderRadius: BorderRadius.circular(WzRadius.xl),
        border: Border.all(color: elevated ? WzColors.border : WzColors.borderSoft),
        boxShadow: elevated ? shadows : softShadows,
      );

  static BoxDecoration sculpted({bool selected = false}) => BoxDecoration(
        gradient: selected
            ? const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFEAF4FB)])
            : const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF5F8FA)]),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(34),
          topRight: Radius.circular(46),
          bottomLeft: Radius.circular(46),
          bottomRight: Radius.circular(30),
        ),
        border: Border.all(color: selected ? const Color(0xFFB9D4E8) : WzColors.borderSoft),
        boxShadow: selected ? liftedShadows : softShadows,
      );

  static BoxDecoration selected({Color? glow}) => BoxDecoration(
        color: WzColors.surfaceElevated,
        borderRadius: BorderRadius.circular(WzRadius.lg),
        border: Border.all(color: WzColors.accent.withValues(alpha: 0.46)),
        boxShadow: [
          BoxShadow(color: (glow ?? WzColors.accent).withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10)),
          const BoxShadow(color: Color(0x66FFFFFF), blurRadius: 8, offset: Offset(0, -2)),
        ],
      );

  static const List<BoxShadow> shadows = [
    BoxShadow(color: Color(0x150D2538), blurRadius: 34, offset: Offset(0, 16)),
    BoxShadow(color: Color(0xBFFFFFFF), blurRadius: 10, offset: Offset(-2, -4)),
  ];

  static const List<BoxShadow> softShadows = [
    BoxShadow(color: Color(0x100D2538), blurRadius: 22, offset: Offset(0, 9)),
    BoxShadow(color: Color(0x99FFFFFF), blurRadius: 8, offset: Offset(-2, -3)),
  ];

  static const List<BoxShadow> liftedShadows = [
    BoxShadow(color: Color(0x1C416A88), blurRadius: 30, offset: Offset(0, 14)),
    BoxShadow(color: Color(0xCCFFFFFF), blurRadius: 12, offset: Offset(-3, -5)),
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
            WzSculptedIcon(icon: icon!, size: 42),
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
  Widget build(BuildContext context) => AnimatedContainer(
        duration: WzMotion.normal,
        curve: WzMotion.curve,
        decoration: WzSurface.panel().copyWith(gradient: gradient),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(WzRadius.xl),
          child: Padding(padding: padding, child: child),
        ),
      );
}

class WzGlassCard extends StatelessWidget {
  const WzGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.gradient,
    this.borderRadius = WzRadius.sculpted,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: gradient ??
                  const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xEEFFFFFF), Color(0xDDF7FAFC)],
                  ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: const Color(0xCCFFFFFF)),
              boxShadow: WzSurface.softShadows,
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      );
}

class WzPressableSurface extends StatefulWidget {
  const WzPressableSurface({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = EdgeInsets.zero,
    this.radius = WzRadius.lg,
    this.decoration,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Decoration? decoration;

  @override
  State<WzPressableSurface> createState() => _WzPressableSurfaceState();
}

class _WzPressableSurfaceState extends State<WzPressableSurface> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
        duration: WzMotion.fast,
        curve: WzMotion.pressCurve,
        scale: _pressed ? 0.982 : 1,
        child: DecoratedBox(
          decoration: widget.decoration ?? WzSurface.sculpted(),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(widget.radius),
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
              onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
              onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
              splashColor: WzColors.accent.withValues(alpha: 0.10),
              highlightColor: Colors.white.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(widget.radius),
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      );
}

class WzSculptedIcon extends StatelessWidget {
  const WzSculptedIcon({super.key, required this.icon, this.size = 48, this.iconSize = 20, this.color});

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: WzSurface.sculpted(),
        alignment: Alignment.center,
        child: Icon(icon, size: iconSize, color: color ?? WzColors.textPrimary),
      );
}

class WzSculptedIconButton extends StatelessWidget {
  const WzSculptedIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 48,
    this.iconSize = 21,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: size,
      height: size,
      child: WzPressableSurface(
        onTap: onPressed,
        radius: size / 2,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Color(0xFFE8F3FB), Color(0xFFFFFFFF)])
              : const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF4F7F9)]),
          shape: BoxShape.circle,
          border: Border.all(color: selected ? const Color(0xFFB9D5E8) : WzColors.borderSoft),
          boxShadow: WzSurface.softShadows,
        ),
        child: Center(child: Icon(icon, size: iconSize, color: onPressed == null ? WzColors.textSubtle : WzColors.textPrimary)),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: WzText.caption.copyWith(color: WzColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
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
          color: active ? const Color(0xFFEAF4F0) : const Color(0xCCFFFFFF),
          borderRadius: BorderRadius.circular(WzRadius.md),
          border: Border.all(color: active ? WzColors.success.withValues(alpha: 0.25) : WzColors.borderSoft),
          boxShadow: WzSurface.softShadows,
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
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: WzColors.textPrimary, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
