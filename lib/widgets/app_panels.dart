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

class ProtocolScreenScaffold extends StatelessWidget {
  final Widget mainContent;
  final Widget sideContent;
  final Widget? topSummary;
  final bool forceTwoColumn;

  const ProtocolScreenScaffold({
    super.key,
    required this.mainContent,
    required this.sideContent,
    this.topSummary,
    this.forceTwoColumn = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final useTwoColumn = forceTwoColumn ||
            (isLandscape && constraints.maxWidth >= 700);

        if (useTwoColumn) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: mainContent),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [if (topSummary != null) topSummary!, sideContent],
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            if (topSummary != null) topSummary!,
            Expanded(child: mainContent),
            sideContent,
          ],
        );
      },
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

class ConnectionSummaryBar extends StatelessWidget {
  final bool isConnected;
  final String statusLabel;
  final String endpointLabel;
  final String speedLabel;
  final String? modeLabel;
  final VoidCallback onToggleConnection;
  final bool isPaused;
  final VoidCallback? onTogglePause;
  final bool showConnectButton;

  const ConnectionSummaryBar({
    super.key,
    required this.isConnected,
    required this.statusLabel,
    required this.endpointLabel,
    required this.speedLabel,
    this.modeLabel,
    required this.onToggleConnection,
    required this.isPaused,
    this.onTogglePause,
    this.showConnectButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = isConnected ? const Color(0xFF059669) : scheme.outline;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SectionBadge(
                  icon: isConnected
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  label: statusLabel,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                SectionBadge(icon: Icons.dns_rounded, label: endpointLabel),
                const SizedBox(width: 8),
                SectionBadge(icon: Icons.speed_rounded, label: speedLabel),
                if (modeLabel != null) ...[
                  const SizedBox(width: 8),
                  SectionBadge(icon: Icons.send_rounded, label: modeLabel!),
                ],
              ],
            ),
          ),
          if (showConnectButton || onTogglePause != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (showConnectButton)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onToggleConnection,
                      icon: Icon(isConnected ? Icons.link_off_rounded : Icons.link_rounded),
                      label: Text(isConnected ? '断开连接' : '连接'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isConnected ? scheme.error : null,
                      ),
                    ),
                  ),
                if (showConnectButton) const SizedBox(width: 8),
                if (onTogglePause != null)
                  IconButton.filledTonal(
                    onPressed: onTogglePause,
                    icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
