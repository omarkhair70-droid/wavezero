import 'package:flutter/material.dart';

import '../../design/wavezero_design_system.dart';

class WzEmptyCatalogMessage extends StatelessWidget {
  const WzEmptyCatalogMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: WzColors.surfaceMuted,
          borderRadius: BorderRadius.circular(WzRadius.md),
        ),
        child: Text(message, style: WzText.body),
      );
}
