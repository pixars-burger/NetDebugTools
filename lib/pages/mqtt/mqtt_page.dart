import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme_controller.dart';
import '../../models/message_data.dart';
import '../../services/mqtt_service.dart';
import '../../services/send_history_service.dart';
import '../../utils/constants.dart';
import '../../utils/data_converter.dart';
import '../../widgets/widgets.dart';

class MqttPage extends StatefulWidget {
  const MqttPage({super.key});

  @override
  State<MqttPage> createState() => _MqttPageState();
}

class _MqttPageState extends State<MqttPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _hostController = TextEditingController(text: 'broker.emqx.io');
  final _portController = TextEditingController(text: '1883');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _wsPathController = TextEditingController(text: '/mqtt');

  final _subscribeTopicController = TextEditingController(text: 'test/topic');
  final _publishTopicController = TextEditingController(text: 'test/topic');
  final _publishMessageController = TextEditingController();
  final _publishMessageFocusNode = FocusNode();

  bool _useWebSocket = false;
  bool _useWss = false;
  MqttQos _subscribeQos = MqttQos.atMostOnce;
  MqttQos _publishQos = MqttQos.atMostOnce;
  DataFormat _receiveFormat = DataFormat.text;
  CharEncoding _encoding = CharEncoding.utf8;

  List<String> _sendHistory = [];
  List<String> _topicHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedConfig();
    _loadSendHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _wsPathController.dispose();
    _subscribeTopicController.dispose();
    _publishTopicController.dispose();
    _publishMessageController.dispose();
    _publishMessageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    final config = SendHistoryService.instance.getMqttConfig();
    setState(() {
      _hostController.text = config['host'] as String;
      _portController.text = (config['port'] as int).toString();
      _usernameController.text = config['username'] as String;
      _useWebSocket = config['useWebSocket'] as bool;
      _useWss = config['useWss'] as bool;
      _wsPathController.text = config['wsPath'] as String;
      _subscribeTopicController.text = SendHistoryService.instance
          .getLastSubTopic();
      _publishTopicController.text = SendHistoryService.instance
          .getLastPubTopic();
      _topicHistory = SendHistoryService.instance.mqttTopicHistory;
    });
  }

  Future<void> _loadSendHistory() async {
    setState(() {
      _sendHistory = SendHistoryService.instance.mqttHistory;
      _topicHistory = SendHistoryService.instance.mqttTopicHistory;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttService>(
      builder: (context, service, child) {
        final errorWidget = service.errorMessage != null
            ? Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ErrorDisplay(
                  errorMessage: service.errorMessage,
                  onDismiss: service.clearError,
                ),
              )
            : null;

        return ProtocolScreenScaffold(
          topSummary: Column(
            children: [
              _buildTopActions(service),
              if (service.droppedMessages > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '已丢弃 ${service.droppedMessages} 条历史消息',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              if (errorWidget != null) errorWidget,
            ],
          ),
          mainContent: Column(
            children: [
              _buildTabStrip(service),
              Expanded(child: _buildPortraitTabContent(service)),
            ],
          ),
          sideContent: Column(
            children: [
              _buildConnectionSummary(service),
              _buildFormatSelector(),
              _buildPublishComposer(service),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionSummary(MqttService service) {
    final summary =
        '${_hostController.text.trim()}:${_portController.text.trim()}';
    final speed =
        '↑${service.statistics.formattedSentBytes} ↓${service.statistics.formattedReceivedBytes}';

    return ConnectionSummaryBar(
      isConnected: service.isConnected,
      statusLabel: service.isConnected ? 'Broker 已连接' : 'Broker 未连接',
      endpointLabel: summary,
      speedLabel: speed,
      modeLabel: '文本发布',
      onToggleConnection: () => _toggleConnection(service),
      showConnectButton: false,
      isPaused: service.isPaused,
      onTogglePause: null,
    );
  }

  Widget _buildTopActions(MqttService service) {
    return Row(
      children: [
        IconButton.outlined(
          onPressed: () => _showConfigSheet(service),
          icon: const Icon(Icons.tune_rounded),
          tooltip: '连接配置',
        ),
        const SizedBox(width: 8),
        Builder(
          builder: (context) {
            final themeController = Provider.of<AppThemeController?>(context);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return IconButton.outlined(
              onPressed: themeController == null
                  ? null
                  : () => themeController.toggleFromBrightness(
                        Theme.of(context).brightness,
                      ),
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              tooltip: '切换明暗主题',
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          onPressed: service.isConnected
              ? () => service.isPaused ? service.resume() : service.pause()
              : null,
          icon: Icon(service.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
          tooltip: '暂停/恢复',
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          onPressed: service.clearMessages,
          icon: const Icon(Icons.delete_sweep_rounded),
          tooltip: '清空消息',
        ),
      ],
    );
  }

  Widget _buildTabStrip(MqttService service) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(height: 34, child: Text('消息 ${service.messages.length}')),
          Tab(height: 34, child: Text('订阅 ${service.subscriptions.length}')),
        ],
      ),
    );
  }

  Widget _buildPortraitTabContent(MqttService service) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildMessageTab(service),
        _buildSubscribeTab(service),
      ],
    );
  }

  Widget _buildMessageTab(MqttService service) {
    return Column(
      children: [
        Expanded(
          child: DataDisplayList(
            messages: service.messages,
            displayFormat: _receiveFormat,
            encoding: _encoding,
            isPaused: service.isPaused,
            onClear: service.clearMessages,
            showToolbar: false,
          ),
        ),
      ],
    );
  }

  Widget _buildFormatSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FormatSelector(
              label: '显示',
              value: _receiveFormat,
              onChanged: (format) => setState(() => _receiveFormat = format),
              dense: true,
            ),
            const SizedBox(width: 6),
            EncodingSelector(
              label: '编码',
              value: _encoding,
              onChanged: (encoding) => setState(() => _encoding = encoding),
              dense: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribeTab(MqttService service) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildSubscribePanel(service),
        const SizedBox(height: 8),
        SizedBox(height: 320, child: _buildSubscriptionsList(service)),
      ],
    );
  }

  Widget _buildSubscribePanel(MqttService service) {
    return AppPanel(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            children: [
              const SectionBadge(icon: Icons.topic_rounded, label: '订阅主题'),
              const Spacer(),
              if (_topicHistory.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: '主题历史',
                  icon: const Icon(Icons.history_rounded),
                  onSelected: (value) {
                    _subscribeTopicController.text = value;
                  },
                  itemBuilder: (context) => _topicHistory
                      .map(
                        (topic) => PopupMenuItem<String>(
                          value: topic,
                          child: Text(topic, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _subscribeTopicController,
            decoration: const InputDecoration(labelText: '主题（支持 + 和 #）'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              DropdownButton<MqttQos>(
                value: _subscribeQos,
                items: MqttQos.values.take(3).map((qos) {
                  return DropdownMenuItem<MqttQos>(
                    value: qos,
                    child: Text('QoS ${qos.index}'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _subscribeQos = value);
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: service.isConnected
                      ? () async {
                          final topic = _subscribeTopicController.text.trim();
                          if (topic.isEmpty) {
                            return;
                          }
                          final canContinue = await _showWildcardRiskIfNeeded(topic);
                          if (!canContinue) {
                            return;
                          }
                          service.subscribe(topic, qos: _subscribeQos);
                          await SendHistoryService.instance.saveLastSubTopic(
                            topic,
                          );
                          _loadSendHistory();
                        }
                      : null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('订阅'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsList(MqttService service) {
    if (service.subscriptions.isEmpty) {
      return const Center(child: Text('暂无订阅'));
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: service.subscriptions.map((sub) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.topic_rounded),
              title: Text(sub.topic),
              subtitle: Text('QoS ${sub.qos.index}'),
              trailing: IconButton(
                icon: const Icon(Icons.unsubscribe_rounded, color: Colors.red),
                onPressed: () => service.unsubscribe(sub.topic),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPublishComposer(MqttService service) {
    return AppPanel(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          TextField(
            controller: _publishTopicController,
            decoration: const InputDecoration(labelText: '发布主题', isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _publishMessageController,
            focusNode: _publishMessageFocusNode,
            decoration: const InputDecoration(labelText: '消息内容', isDense: true),
            maxLines: 2,
            minLines: 1,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              DropdownButton<MqttQos>(
                value: _publishQos,
                items: MqttQos.values.take(3).map((qos) {
                  return DropdownMenuItem<MqttQos>(
                    value: qos,
                    child: Text('QoS ${qos.index}'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _publishQos = value);
                  }
                },
              ),
              const Spacer(),
              SendHistoryDropdown(
                history: _sendHistory,
                onSelect: (value) => _publishMessageController.text = value,
                onClear: () async {
                  await SendHistoryService.instance.clearMqttHistory();
                  _loadSendHistory();
                },
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: service.isConnected ? () => _publish(service) : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('发布'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showConfigSheet(MqttService service) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Consumer<MqttService>(
          builder: (context, liveService, _) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(child: _buildConfigForm(liveService)),
        ));
      },
    );
  }

  bool _isDangerousWildcard(String topic) {
    final normalized = topic.replaceAll(' ', '');
    if (normalized == '#') return true;
    if (normalized == '/#') return true;
    if (normalized == '+/+/#') return true;
    return false;
  }

  Future<bool> _showWildcardRiskIfNeeded(String topic) async {
    if (!_isDangerousWildcard(topic)) {
      return true;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('高风险订阅提示'),
        content: const Text(
          '你正在订阅大范围通配符 Topic。\n\n'
          '这可能导致消息洪峰、界面卡顿、内存上涨甚至应用无响应。\n\n'
          '确认继续订阅吗？',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('继续订阅')),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildConfigForm(MqttService service) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [Text('连接配置', style: Theme.of(context).textTheme.titleMedium)]),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(controller: _hostController, decoration: const InputDecoration(labelText: '服务器地址'), enabled: !service.isConnected),
            ),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _portController, decoration: const InputDecoration(labelText: '端口'), keyboardType: TextInputType.number, enabled: !service.isConnected)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('WebSocket'),
              selected: _useWebSocket,
              onSelected: service.isConnected
                  ? null
                  : (value) {
                      setState(() {
                        _useWebSocket = value;
                        if (!_useWebSocket) {
                          _useWss = false;
                          _portController.text = '1883';
                        } else {
                          _portController.text = _useWss ? '8084' : '8083';
                        }
                      });
                    },
            ),
            FilterChip(
              label: const Text('WSS'),
              selected: _useWss,
              onSelected: (!_useWebSocket || service.isConnected)
                  ? null
                  : (value) {
                      setState(() {
                        _useWss = value;
                        _portController.text = _useWss ? '8084' : '8083';
                      });
                    },
            ),
          ],
        ),
        if (_useWebSocket) ...[
          const SizedBox(height: 10),
          TextField(controller: _wsPathController, decoration: const InputDecoration(labelText: 'WS 路径'), enabled: !service.isConnected),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: TextField(controller: _usernameController, decoration: const InputDecoration(labelText: '用户名（可选）'), enabled: !service.isConnected)),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _passwordController, decoration: const InputDecoration(labelText: '密码（可选）'), obscureText: true, enabled: !service.isConnected)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => _toggleConnection(service),
              icon: Icon(service.isConnected ? Icons.link_off_rounded : Icons.link_rounded),
              label: Text(service.isConnected ? '断开' : '连接'),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: service.isConnected
                  ? () => service.isPaused ? service.resume() : service.pause()
                  : null,
              icon: Icon(service.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _toggleConnection(MqttService service) async {
    if (service.isConnected) {
      await service.disconnect();
      return;
    }

    final host = _hostController.text.trim();
    final port =
        int.tryParse(_portController.text.trim()) ??
        AppConstants.defaultMqttPort;
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final wsPath = _wsPathController.text.trim();

    if (host.isEmpty) {
      return;
    }

    await SendHistoryService.instance.saveMqttConfig(
      host: host,
      port: port,
      username: username,
      useWebSocket: _useWebSocket,
      useWss: _useWss,
      wsPath: wsPath,
    );

    await service.connect(
      host: host,
      port: port,
      username: username.isNotEmpty ? username : null,
      password: password.isNotEmpty ? password : null,
      useWebSocket: _useWebSocket,
      useWss: _useWss,
      wsPath: wsPath.isNotEmpty ? wsPath : '/mqtt',
    );
    if (mounted) setState(() {});
  }

  Future<void> _publish(MqttService service) async {
    final topic = _publishTopicController.text.trim();
    final message = _publishMessageController.text;
    if (topic.isEmpty || message.isEmpty) {
      return;
    }

    final result = DataConverter.stringToBytes(
      message,
      DataFormat.text,
      _encoding,
    );
    if (!result.isSuccess) {
      return;
    }

    final success = await service.publish(
      topic,
      result.data!,
      qos: _publishQos,
    );
    if (!success) {
      return;
    }

    await SendHistoryService.instance.addMqttHistory(message);
    await SendHistoryService.instance.saveLastPubTopic(topic);
    _loadSendHistory();
  }
}
