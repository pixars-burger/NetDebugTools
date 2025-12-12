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

  // 连接配置
  final _hostController = TextEditingController(text: 'broker.emqx.io');
  final _portController = TextEditingController(text: '1883');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _wsPathController = TextEditingController(text: '/mqtt');
  bool _useWebSocket = false;
  bool _useWss = false;

  // 订阅配置
  final _subscribeTopicController = TextEditingController(text: 'test/topic');
  MqttQos _subscribeQos = MqttQos.atMostOnce;

  // 发布配置
  final _publishTopicController = TextEditingController(text: 'test/topic');
  final _publishMessageController = TextEditingController();
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
    super.dispose();
  }

  Future<void> _loadSendHistory() async {
    final history = SendHistoryService.instance.mqttHistory;
    final topics = SendHistoryService.instance.mqttTopicHistory;
    setState(() {
      _sendHistory = history;
      _topicHistory = topics;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttService>(
      builder: (context, service, child) {
        return Column(
          children: [
            // 连接配置区域
            _buildConnectionConfig(service),
            // 错误提示
            if (service.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ErrorDisplay(
                  errorMessage: service.errorMessage,
                  onDismiss: () => service.clearError(),
                ),
              ),
            // 统计信息
            CompactStatisticsPanel(
              statistics: service.statistics,
              onReset: () => service.resetStatistics(),
            ),
            // Tab栏
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: '消息 (${service.messages.length})'),
                Tab(text: '订阅 (${service.subscriptions.length})'),
                const Tab(text: '发布'),
              ],
            ),
            // Tab内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 消息列表
                  _buildMessageTab(service),
                  // 订阅管理
                  _buildSubscribeTab(service),
                  // 发布消息
                  _buildPublishTab(service),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionConfig(MqttService service) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 服务器地址和端口
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    enabled: !service.isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !service.isConnected,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // WebSocket配置
            Row(
              children: [
                Checkbox(
                  value: _useWebSocket,
                  onChanged: service.isConnected
                      ? null
                      : (value) {
                          setState(() {
                            _useWebSocket = value ?? false;
                            if (!_useWebSocket) _useWss = false;
                            // 更新默认端口
                            if (_useWebSocket) {
                              _portController.text = _useWss ? '8084' : '8083';
                            } else {
                              _portController.text = '1883';
                            }
                          });
                        },
                ),
                const Text('WebSocket'),
                const SizedBox(width: 16),
                Checkbox(
                  value: _useWss,
                  onChanged: (!_useWebSocket || service.isConnected)
                      ? null
                      : (value) {
                          setState(() {
                            _useWss = value ?? false;
                            _portController.text = _useWss ? '8084' : '8083';
                          });
                        },
                ),
                const Text('WSS'),
                const SizedBox(width: 8),
                if (_useWebSocket)
                  Expanded(
                    child: TextField(
                      controller: _wsPathController,
                      decoration: const InputDecoration(
                        labelText: 'WS路径',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      enabled: !service.isConnected,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 认证配置
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名（可选）',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    enabled: !service.isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: '密码（可选）',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    enabled: !service.isConnected,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 连接按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleConnection(service),
                    icon: Icon(
                      service.isConnected ? Icons.link_off : Icons.link,
                      size: 18,
                    ),
                    label: Text(service.isConnected ? '断开连接' : '连接'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: service.isConnected
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 暂停/继续按钮
                IconButton(
                  onPressed: service.isConnected
                      ? () {
                          if (service.isPaused) {
                            service.resume();
                          } else {
                            service.pause();
                          }
                        }
                      : null,
                  icon: Icon(service.isPaused ? Icons.play_arrow : Icons.pause),
                  tooltip: service.isPaused ? '继续接收' : '暂停接收',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTab(MqttService service) {
    return Column(
      children: [
        // 格式和编码选择
        Padding(
          padding: const EdgeInsets.all(8),
          child: FormatEncodingSelector(
            format: _receiveFormat,
            encoding: _encoding,
            onFormatChanged: (format) =>
                setState(() => _receiveFormat = format),
            onEncodingChanged: (encoding) =>
                setState(() => _encoding = encoding),
            formatLabel: '格式',
            encodingLabel: '编码',
          ),
        ),
        // 消息列表
        Expanded(
          child: DataDisplayList(
            messages: service.messages,
            displayFormat: _receiveFormat,
            encoding: _encoding,
            isPaused: service.isPaused,
            onClear: () => service.clearMessages(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscribeTab(MqttService service) {
    return Column(
      children: [
        // 订阅配置
        Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    if (_topicHistory.isNotEmpty)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.history, size: 20),
                        tooltip: '主题历史',
                        onSelected: (value) {
                          _subscribeTopicController.text = value;
                        },
                        itemBuilder: (context) => _topicHistory
                            .map(
                              (topic) => PopupMenuItem(
                                value: topic,
                                child: Text(
                                  topic,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _subscribeTopicController,
                        decoration: const InputDecoration(
                          labelText: '主题（支持通配符 + 和 #）',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<MqttQos>(
                      value: _subscribeQos,
                      items: MqttQos.values.take(3).map((qos) {
                        return DropdownMenuItem(
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
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: service.isConnected
                        ? () async {
                            final topic = _subscribeTopicController.text.trim();
                            if (topic.isNotEmpty) {
                              service.subscribe(topic, qos: _subscribeQos);
                              await SendHistoryService.instance
                                  .saveLastSubTopic(topic);
                              _loadSendHistory();
                            }
                          }
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('订阅'),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 已订阅主题列表
        Expanded(
          child: service.subscriptions.isEmpty
              ? const Center(child: Text('暂无订阅'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: service.subscriptions.length,
                  itemBuilder: (context, index) {
                    final sub = service.subscriptions[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.topic),
                        title: Text(sub.topic),
                        subtitle: Text('QoS ${sub.qos.index}'),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.unsubscribe,
                            color: Colors.red,
                          ),
                          onPressed: () => service.unsubscribe(sub.topic),
                          tooltip: '取消订阅',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPublishTab(MqttService service) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 发布配置
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 主题 - 带历史记录
                  Row(
                    children: [
                      if (_topicHistory.isNotEmpty)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.history, size: 20),
                          tooltip: '主题历史',
                          onSelected: (value) {
                            _publishTopicController.text = value;
                          },
                          itemBuilder: (context) => _topicHistory
                              .map(
                                (topic) => PopupMenuItem(
                                  value: topic,
                                  child: Text(
                                    topic,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      Expanded(
                        child: TextField(
                          controller: _publishTopicController,
                          decoration: const InputDecoration(
                            labelText: '发布主题',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // QoS、格式和编码
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('QoS: '),
                          DropdownButton<MqttQos>(
                            value: _publishQos,
                            items: MqttQos.values.take(3).map((qos) {
                              return DropdownMenuItem(
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
                        ],
                      ),
                      FormatSelector(
                        label: '格式',
                        value: _sendFormat,
                        onChanged: (format) =>
                            setState(() => _sendFormat = format),
                        dense: true,
                      ),
                      EncodingSelector(
                        label: '编码',
                        value: _encoding,
                        onChanged: (encoding) =>
                            setState(() => _encoding = encoding),
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 消息内容 - 增大高度
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SendHistoryDropdown(
                        history: _sendHistory,
                        onSelect: (value) {
                          _publishMessageController.text = value;
                        },
                        onClear: () async {
                          await SendHistoryService.instance.clearMqttHistory();
                          _loadSendHistory();
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _publishMessageController,
                          decoration: const InputDecoration(
                            labelText: '消息内容',
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: '支持多行输入...',
                          ),
                          maxLines: 6,
                          minLines: 4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 发布按钮
                  ElevatedButton.icon(
                    onPressed: service.isConnected
                        ? () => _publish(service)
                        : null,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('发布'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleConnection(MqttService service) async {
    if (service.isConnected) {
      await service.disconnect();
    } else {
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

      // 保存连接配置
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
    if (success) {
      // 保存到历史
      await SendHistoryService.instance.addMqttHistory(message);
      await SendHistoryService.instance.saveLastPubTopic(topic);
      _loadSendHistory();
    }
  }
}
