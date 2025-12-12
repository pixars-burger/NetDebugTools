import 'package:flutter/material.dart';
import '../models/statistics.dart';

/// 统计信息面板组件
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
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '统计信息',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (onReset != null)
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('重置'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStatRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _StatItem(
          icon: Icons.upload,
          label: '发送',
          value:
              '${statistics.formattedSentBytes} / ${statistics.sentPackets} 包',
          color: Colors.blue,
        ),
        _StatItem(
          icon: Icons.download,
          label: '接收',
          value:
              '${statistics.formattedReceivedBytes} / ${statistics.receivedPackets} 包',
          color: Colors.green,
        ),
        if (showDuration && statistics.startTime != null)
          _StatItem(
            icon: Icons.timer,
            label: '时长',
            value: statistics.formattedDuration,
            color: Colors.orange,
          ),
      ],
    );
  }
}

/// 统计项组件
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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

/// 紧凑版统计面板
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '↑ ${statistics.formattedSentBytes}/${statistics.sentPackets}包  '
              '↓ ${statistics.formattedReceivedBytes}/${statistics.receivedPackets}包',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (statistics.startTime != null)
            Text(
              statistics.formattedDuration,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          if (onReset != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onReset,
              child: Icon(
                Icons.refresh,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
