import 'package:flutter/material.dart';

import '../models/statistics.dart';

class StatisticsPanel extends StatelessWidget {
  final Statistics statistics;
  final VoidCallback? onReset;
  final bool showDuration;

  const StatisticsPanel({
    super.key,
    required this.statistics,
    this.onReset,
    this.showDuration = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '统计信息',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (onReset != null)
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('重置'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatItem(
          icon: Icons.north_east_rounded,
          label: '发送',
          value: '${statistics.formattedSentBytes} / ${statistics.sentPackets}',
          color: const Color(0xFF2563EB),
        ),
        _StatItem(
          icon: Icons.south_west_rounded,
          label: '接收',
          value:
              '${statistics.formattedReceivedBytes} / ${statistics.receivedPackets}',
          color: const Color(0xFF059669),
        ),
        if (showDuration && statistics.startTime != null)
          _StatItem(
            icon: Icons.timer_outlined,
            label: '时长',
            value: statistics.formattedDuration,
            color: const Color(0xFFF97316),
          ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.9),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CompactStatisticsPanel extends StatelessWidget {
  final Statistics statistics;
  final VoidCallback? onReset;

  const CompactStatisticsPanel({
    super.key,
    required this.statistics,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLow],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.data_usage_rounded, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '↑ ${statistics.formattedSentBytes}/${statistics.sentPackets}   '
              '↓ ${statistics.formattedReceivedBytes}/${statistics.receivedPackets}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (statistics.startTime != null) ...[
            const SizedBox(width: 6),
            Text(
              statistics.formattedDuration,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
          if (onReset != null) ...[
            const SizedBox(width: 4),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onReset,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
