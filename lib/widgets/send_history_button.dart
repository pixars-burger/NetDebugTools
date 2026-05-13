import 'package:flutter/material.dart';

class SendHistoryButton extends StatelessWidget {
  final List<String> history;
  final ValueChanged<String> onSelect;
  final VoidCallback? onClear;
  final String tooltip;
  final String clearText;

  const SendHistoryButton({
    super.key,
    required this.history,
    required this.onSelect,
    this.onClear,
    this.tooltip = '发送历史',
    this.clearText = '清空历史',
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.history_rounded),
      tooltip: tooltip,
      onSelected: (value) {
        if (value == '__clear__') {
          onClear?.call();
          return;
        }
        onSelect(value);
      },
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
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    clearText,
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

class SendHistoryDropdown extends StatelessWidget {
  final List<String> history;
  final ValueChanged<String> onSelect;
  final VoidCallback? onClear;
  final String tooltip;
  final String title;
  final String emptyText;
  final String clearText;

  const SendHistoryDropdown({
    super.key,
    required this.history,
    required this.onSelect,
    this.onClear,
    this.tooltip = '发送历史',
    this.title = '发送历史',
    this.emptyText = '暂无发送历史',
    this.clearText = '清空',
  });

  void _showHistoryDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.58,
        minChildSize: 0.32,
        maxChildSize: 0.88,
        expand: false,
        builder: (context, scrollController) {
          final scheme = Theme.of(context).colorScheme;

          return DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (onClear != null && history.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            onClear!();
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: Text(clearText),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: history.isEmpty
                      ? Center(child: Text(emptyText))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final item = history[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.schedule_rounded,
                                size: 18,
                              ),
                              title: Text(
                                item,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
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
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () => _showHistoryDialog(context),
      icon: Badge(
        isLabelVisible: history.isNotEmpty,
        label: Text(
          history.length.toString(),
          style: const TextStyle(fontSize: 10),
        ),
        child: const Icon(Icons.history_rounded),
      ),
    );
  }
}
