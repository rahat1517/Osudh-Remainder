import 'package:material_ui/material_ui.dart';

import '../data/models.dart';

/// Visual treatment of a field by confidence: high is plain, medium is amber, low is red-tinted.
({Color? fill, Color border, IconData? icon}) confidenceStyle(
  BuildContext context,
  Confidence c,
  bool reviewed,
) {
  final scheme = Theme.of(context).colorScheme;
  if (reviewed || c == Confidence.high) {
    return (fill: null, border: scheme.outline, icon: null);
  }
  return switch (c) {
    Confidence.medium => (
      fill: const Color(0x33FFC107),
      border: const Color(0xFFFFA000),
      icon: Icons.help_outline,
    ),
    _ => (
      fill: scheme.errorContainer.withValues(alpha: 0.4),
      border: scheme.error,
      icon: Icons.error_outline,
    ),
  };
}
