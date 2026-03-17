import 'package:flutter/material.dart';

class AppPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const AppPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Card(
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SplitView extends StatelessWidget {
  final Widget main;
  final Widget side;
  final int mainFlex;
  final int sideFlex;

  const SplitView({
    super.key,
    required this.main,
    required this.side,
    this.mainFlex = 5,
    this.sideFlex = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: mainFlex, child: main),
        const SizedBox(width: 8),
        Expanded(
          flex: sideFlex,
          child: SingleChildScrollView(child: side),
        ),
      ],
    );
  }
}

class SectionBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const SectionBadge({super.key, required this.label, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = color ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tone),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}
