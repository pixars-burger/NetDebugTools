import 'package:flutter/material.dart';
import '../models/message_data.dart';
import '../utils/timestamp_formatter.dart';
import '../utils/data_converter.dart';

/// 数据展示列表组件
class DataDisplayList extends StatefulWidget {
  final List<MessageData> messages;
  final DataFormat displayFormat;
  final CharEncoding encoding;
  final bool isPaused;
  final VoidCallback? onClear;
  final ScrollController? scrollController;

  const DataDisplayList({
    super.key,
    required this.messages,
    required this.displayFormat,
    this.encoding = CharEncoding.utf8,
    this.isPaused = false,
    this.onClear,
    this.scrollController,
  });

  @override
  State<DataDisplayList> createState() => _DataDisplayListState();
}

class _DataDisplayListState extends State<DataDisplayList> {
  late ScrollController _scrollController;
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
    // 当新消息到达且自动滚动启用时，滚动到底部
    if (widget.messages.length > oldWidget.messages.length &&
        _autoScrollEnabled &&
        !widget.isPaused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _onScroll() {
    if (_isUserScrolling) {
      // 检查是否滚动到底部
      final isAtBottom =
          _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50;

      if (isAtBottom != _autoScrollEnabled) {
        setState(() {
          _autoScrollEnabled = isAtBottom;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工具栏
        _buildToolbar(context),
        // 消息列表
        Expanded(
          child: widget.messages.isEmpty
              ? _buildEmptyState(context)
              : _buildMessageList(context),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text(
            '共 ${widget.messages.length} 条消息',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          if (widget.isPaused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '已暂停',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          if (!_autoScrollEnabled) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                setState(() {
                  _autoScrollEnabled = true;
                });
                _scrollToBottom();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      size: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '回到底部',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (widget.onClear != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: widget.onClear,
              tooltip: '清空消息',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 8),
          Text(
            '暂无数据',
            style: TextStyle(color: Theme.of(context).disabledColor),
          ),
        ],
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
        padding: const EdgeInsets.all(8),
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

/// 消息项组件
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
    final isSent = message.isSent;
    final color = isSent ? Colors.blue : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部信息 - 使用Wrap避免溢出
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 发送/接收标识
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSent ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isSent ? '发送' : '接收',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
              if (message.source != null)
                Text(
                  '来自: ${message.source}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              if (message.topic != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    message.topic!,
                    style: const TextStyle(fontSize: 11, color: Colors.purple),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (message.qos != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'QoS${message.qos}',
                    style: const TextStyle(fontSize: 10, color: Colors.orange),
                  ),
                ),
              // 时间戳和大小
              Text(
                '${TimestampFormatter.formatShort(message.timestamp)} | ${message.length} B',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 数据内容
          SelectableText(
            DataConverter.bytesToString(message.data, displayFormat, encoding),
            style: TextStyle(
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
