import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:provider/provider.dart';

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
  bool _configExpanded = true;
  MqttQos _subscribeQos = MqttQos.atMostOnce;
  MqttQos _publishQos = MqttQos.atMostOnce;
  DataFormat _sendFormat = DataFormat.text;
  DataFormat _receiveFormat = DataFormat.text;
  CharEncoding _encoding = CharEncoding.utf8;

  List<String> _sendHistory = [];
  List<String> _topicHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final landscape =
                constraints.maxWidth > constraints.maxHeight &&
                constraints.maxWidth >= 700;
            final keyboardVisible = View.of(context).viewInsets.bottom > 0;
            final compactForInput =
                keyboardVisible && _publishMessageFocusNode.hasFocus;

            final errorWidget = service.errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ErrorDisplay(
                      errorMessage: service.errorMessage,
                      onDismiss: service.clearError,
                    ),
                  )
                : null;

            if (landscape) {
              return SplitView(
                mainFlex: 7,
                sideFlex: 4,
                main: Column(
                  children: [
                    CompactStatisticsPanel(
                      statistics: service.statistics,
                      onReset: service.resetStatistics,
                    ),
                    _buildTabStrip(service),
                    Expanded(child: _buildLandscapeMainContent(service)),
                  ],
                ),
                side: Column(
                  children: [
                    _buildConnectionConfig(service),
                    if (errorWidget != null) errorWidget,
                    _buildLandscapeSideContent(service),
                  ],
                ),
              );
            }

            return Column(
              children: [
                if (!compactForInput) _buildConnectionConfig(service),
                if (!compactForInput && errorWidget != null) errorWidget,
                if (!compactForInput)
                  CompactStatisticsPanel(
                    statistics: service.statistics,
                    onReset: service.resetStatistics,
                  ),
                if (!compactForInput) _buildTabStrip(service),
                Expanded(child: _buildPortraitTabContent(service)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildConnectionConfig(MqttService service) {
    final summary =
        '${_hostController.text.trim()}:${_portController.text.trim()}';

    return AppPanel(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SectionBadge(
                        icon: service.isConnected
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        label: service.isConnected
                            ? 'Broker 已连接'
                            : 'Broker 未连接',
                        color: service.isConnected
                            ? const Color(0xFF059669)
                            : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      SectionBadge(
                        icon: _useWebSocket
                            ? Icons.language_rounded
                            : Icons.settings_ethernet_rounded,
                        label: _useWebSocket
                            ? (_useWss ? 'WSS' : 'WebSocket')
                            : 'TCP',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      SectionBadge(
                        icon: Icons.dns_rounded,
                        label: summary,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _configExpanded = !_configExpanded);
                },
                icon: Icon(
                  _configExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _toggleConnection(service),
                  icon: Icon(
                    service.isConnected
                        ? Icons.link_off_rounded
                        : Icons.link_rounded,
                  ),
                  label: Text(service.isConnected ? '断开连接' : '连接 Broker'),
                  style: FilledButton.styleFrom(
                    backgroundColor: service.isConnected
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: service.isConnected
                      ? () {
                          service.isPaused ? service.resume() : service.pause();
                        }
                      : null,
                  icon: Icon(
                    service.isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                ),
              ],
            ),
          ),
          if (_configExpanded) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(labelText: '服务器地址'),
                    enabled: !service.isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(labelText: '端口'),
                    keyboardType: TextInputType.number,
                    enabled: !service.isConnected,
                  ),
                ),
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
              TextField(
                controller: _wsPathController,
                decoration: const InputDecoration(labelText: 'WS 路径'),
                enabled: !service.isConnected,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: '用户名（可选）'),
                    enabled: !service.isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: '密码（可选）'),
                    obscureText: true,
                    enabled: !service.isConnected,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
          const Tab(height: 34, child: Text('发布')),
        ],
      ),
    );
  }

  Widget _buildLandscapeMainContent(MqttService service) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        switch (_tabController.index) {
          case 1:
            return _buildSubscriptionsList(service);
          case 2:
            return _buildPublishHint();
          case 0:
          default:
            return DataDisplayList(
              messages: service.messages,
              displayFormat: _receiveFormat,
              encoding: _encoding,
              isPaused: service.isPaused,
              onClear: service.clearMessages,
            );
        }
      },
    );
  }

  Widget _buildLandscapeSideContent(MqttService service) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        switch (_tabController.index) {
          case 1:
            return _buildSubscribePanel(service);
          case 2:
            return _buildPublishPanel(service);
          case 0:
          default:
            return _buildMessageControlPanel(service);
        }
      },
    );
  }

  Widget _buildPortraitTabContent(MqttService service) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildMessageTab(service),
        _buildSubscribeTab(service),
        _buildPublishTab(service),
      ],
    );
  }

  Widget _buildMessageTab(MqttService service) {
    final keyboardVisible = View.of(context).viewInsets.bottom > 0;
    final compactForInput =
        keyboardVisible && _publishMessageFocusNode.hasFocus;

    return Column(
      children: [
        if (!compactForInput) _buildMessageControlRow(),
        Expanded(
          child: DataDisplayList(
            messages: service.messages,
            displayFormat: _receiveFormat,
            encoding: _encoding,
            isPaused: service.isPaused,
            onClear: service.clearMessages,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageControlPanel(MqttService service) {
    return Column(
      children: [
        _buildMessageControlRow(),
        AppPanel(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionBadge(
                icon: Icons.tips_and_updates_rounded,
                label: service.isPaused ? '消息接收已暂停' : '当前显示实时消息',
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                '横屏下消息列表固定在中间主区域，格式和清空操作集中到右侧控制区。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageControlRow() {
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

  Widget _buildPublishTab(MqttService service) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [_buildPublishPanel(service)],
    );
  }

  Widget _buildPublishPanel(MqttService service) {
    return AppPanel(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            children: [
              const SectionBadge(icon: Icons.publish_rounded, label: '消息发布'),
              const Spacer(),
              if (_topicHistory.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: '主题历史',
                  icon: const Icon(Icons.history_rounded),
                  onSelected: (value) {
                    _publishTopicController.text = value;
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
            controller: _publishTopicController,
            decoration: const InputDecoration(labelText: '发布主题'),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
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
                const SizedBox(width: 8),
                FormatSelector(
                  label: '格式',
                  value: _sendFormat,
                  onChanged: (format) => setState(() => _sendFormat = format),
                  dense: true,
                ),
                const SizedBox(width: 8),
                EncodingSelector(
                  label: '编码',
                  value: _encoding,
                  onChanged: (encoding) => setState(() => _encoding = encoding),
                  dense: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SendHistoryDropdown(
                history: _sendHistory,
                onSelect: (value) => _publishMessageController.text = value,
                onClear: () async {
                  await SendHistoryService.instance.clearMqttHistory();
                  _loadSendHistory();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _publishMessageController,
                  focusNode: _publishMessageFocusNode,
                  decoration: const InputDecoration(labelText: '消息内容'),
                  maxLines: 4,
                  minLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: service.isConnected ? () => _publish(service) : null,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('发布'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishHint() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '发布操作已移动到右侧控制区，主区域继续保留给消息和订阅内容。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _toggleConnection(MqttService service) async {
    if (service.isConnected) {
      await service.disconnect();
      if (mounted) {
        setState(() => _configExpanded = true);
      }
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
    if (mounted && service.isConnected) {
      setState(() => _configExpanded = false);
    }
  }

  Future<void> _publish(MqttService service) async {
    final topic = _publishTopicController.text.trim();
    final message = _publishMessageController.text;
    if (topic.isEmpty || message.isEmpty) {
      return;
    }

    final result = DataConverter.stringToBytes(message, _sendFormat, _encoding);
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
