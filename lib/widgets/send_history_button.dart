import 'package:flutter/material.dart';

/// 发送历史按钮组件
class SendHistoryButton extends StatelessWidget {
  final List<String> history;
  final ValueChanged<String> onSelect;
  final VoidCallback? onClear;

  const SendHistoryButton({
    super.key,
    required this.history,
    required this.onSelect,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.history),
      tooltip: '发送历史',
      onSelected: onSelect,
      itemBuilder: (context) {
        return [
          ...history.map(
            (item) => PopupMenuItem<String>(
              value: item,
              child: Text(
                item.length > 50 ? '${item.substring(0, 50)}...' : item,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (onClear != null) ...[
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: '__clear__',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '清空历史',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ];
      },
    );
  }
}

/// 发送历史下拉菜单
class SendHistoryDropdown extends StatelessWidget {
  final List<String> history;
  final ValueChanged<String> onSelect;
  final VoidCallback? onClear;

  const SendHistoryDropdown({
    super.key,
    required this.history,
    required this.onSelect,
    this.onClear,
  });

  void _showHistoryDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      '发送历史',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (onClear != null && history.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onClear!();
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('清空'),
                      ),
                  ],
                ),
              ),
              // 历史列表
              Expanded(
                child: history.isEmpty
                    ? const Center(child: Text('暂无发送历史'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final item = history[index];
                          return ListTile(
                            title: Text(
                              item,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              onSelect(item);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Badge(
        isLabelVisible: history.isNotEmpty,
        label: Text(
          history.length.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        child: const Icon(Icons.history),
      ),
      tooltip: '发送历史',
      onPressed: () => _showHistoryDialog(context),
    );
  }
}
