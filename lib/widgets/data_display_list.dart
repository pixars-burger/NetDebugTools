import 'package:flutter/material.dart';

import '../models/message_data.dart';
import '../utils/data_converter.dart';
import '../utils/timestamp_formatter.dart';

class DataDisplayList extends StatefulWidget {
  final List<MessageData> messages;
  final DataFormat displayFormat;
  final CharEncoding encoding;
  final bool isPaused;
  final VoidCallback? onClear;
  final ScrollController? scrollController;
  final bool showToolbar;

  const DataDisplayList({
    super.key,
    required this.messages,
    required this.displayFormat,
    this.encoding = CharEncoding.utf8,
    this.isPaused = false,
    this.onClear,
    this.scrollController,
    this.showToolbar = true,
  });

  @override
  State<DataDisplayList> createState() => _DataDisplayListState();
}

class _DataDisplayListState extends State<DataDisplayList> {
  late final ScrollController _scrollController;
  bool _autoScrollEnabled = true;
  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(DataDisplayList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length &&
        _autoScrollEnabled &&
        !widget.isPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _onScroll() {
    if (!_isUserScrolling || !_scrollController.hasClients) {
      return;
    }

    final isAtBottom =
        _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50;

    if (isAtBottom != _autoScrollEnabled) {
      setState(() => _autoScrollEnabled = isAtBottom);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          if (widget.showToolbar) _buildToolbar(context),
          Expanded(
            child: widget.messages.isEmpty
                ? _buildEmptyState(context)
                : _buildMessageList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Center(
            child: _ToolbarChip(
              icon: Icons.forum_outlined,
              label: '${widget.messages.length} 条消息',
            ),
          ),
          if (widget.isPaused)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Center(
                child: _ToolbarChip(
                  icon: Icons.pause_circle_outline,
                  label: '已暂停',
                  color: Colors.orange,
                ),
              ),
            ),
          if (!_autoScrollEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Center(
                child: ActionChip(
                  avatar: Icon(
                    Icons.arrow_downward_rounded,
                    size: 14,
                    color: scheme.onPrimaryContainer,
                  ),
                  label: const Text('回到底部'),
                  onPressed: () {
                    setState(() => _autoScrollEnabled = true);
                    _scrollToBottom();
                  },
                ),
              ),
            ),
          if (widget.onClear != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Center(
                child: ActionChip(
                  avatar: const Icon(Icons.delete_outline_rounded, size: 14),
                  label: const Text('清空'),
                  onPressed: widget.onClear,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 18, color: scheme.outline),
            const SizedBox(width: 6),
            Text('暂无消息', style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          _isUserScrolling = true;
        } else if (notification is ScrollEndNotification) {
          _isUserScrolling = false;
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        itemCount: widget.messages.length,
        itemBuilder: (context, index) {
          return _MessageItem(
            message: widget.messages[index],
            displayFormat: widget.displayFormat,
            encoding: widget.encoding,
          );
        },
      ),
    );
  }
}

class _ToolbarChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _ToolbarChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageItem extends StatelessWidget {
  final MessageData message;
  final DataFormat displayFormat;
  final CharEncoding encoding;

  const _MessageItem({
    required this.message,
    required this.displayFormat,
    this.encoding = CharEncoding.utf8,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSent = message.isSent;
    final accent = isSent ? const Color(0xFF2563EB) : const Color(0xFF059669);
    final payload = DataConverter.bytesToString(
      message.data,
      displayFormat,
      encoding,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(
                icon: isSent
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                label: isSent ? '发送' : '接收',
                color: accent,
              ),
              _MetaChip(
                icon: Icons.schedule_rounded,
                label:
                    '${TimestampFormatter.formatShort(message.timestamp)} · ${message.length} B',
                color: scheme.onSurfaceVariant,
                filled: false,
              ),
              if (message.source != null)
                _MetaChip(
                  icon: Icons.lan_rounded,
                  label: message.source!,
                  color: scheme.secondary,
                ),
              if (message.topic != null)
                _MetaChip(
                  icon: Icons.tag_rounded,
                  label: message.topic!,
                  color: const Color(0xFF7C3AED),
                ),
              if (message.qos != null)
                _MetaChip(
                  icon: Icons.shield_outlined,
                  label: 'QoS ${message.qos}',
                  color: const Color(0xFFF97316),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            payload,
            style: TextStyle(
              height: 1.35,
              fontSize: 13,
              fontFamily: 'monospace',
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: filled ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
