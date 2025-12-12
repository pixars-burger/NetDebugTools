import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:typed_data/typed_data.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/constants.dart';

/// MQTT订阅信息
class MqttSubscription {
  final String topic;
  final MqttQos qos;

  MqttSubscription({required this.topic, required this.qos});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MqttSubscription &&
          runtimeType == other.runtimeType &&
          topic == other.topic;

  @override
  int get hashCode => topic.hashCode;
}

/// MQTT服务
class MqttService extends ChangeNotifier {
  MqttServerClient? _client;
  ConnectionState _state = ConnectionState.disconnected;
  final Statistics _statistics = Statistics();
  final List<MessageData> _messages = [];
  final List<MqttSubscription> _subscriptions = [];
  String? _errorMessage;
  bool _isPaused = false;

  // 连接配置
  String _host = '';
  int _port = AppConstants.defaultMqttPort;
  String _clientId = '';
  String _username = '';
  String _password = '';
  bool _useWebSocket = false;
  bool _useWss = false;
  String _wsPath = AppConstants.defaultMqttWsPath;
  int _keepAlive = AppConstants.mqttKeepAlive;

  // Getters
  ConnectionState get state => _state;
  Statistics get statistics => _statistics;
  List<MessageData> get messages => List.unmodifiable(_messages);
  List<MqttSubscription> get subscriptions => List.unmodifiable(_subscriptions);
  String? get errorMessage => _errorMessage;
  bool get isPaused => _isPaused;
  bool get isConnected => _state == ConnectionState.connected;
  String get host => _host;
  int get port => _port;
  String get clientId => _clientId;
  String get wsPath => _wsPath;

  /// 连接到MQTT服务器
  Future<bool> connect({
    required String host,
    required int port,
    String? clientId,
    String? username,
    String? password,
    bool useWebSocket = false,
    bool useWss = false,
    String wsPath = '/mqtt',
    int keepAlive = 60,
  }) async {
    if (_state == ConnectionState.connecting ||
        _state == ConnectionState.connected) {
      return false;
    }

    _host = host;
    _port = port;
    _clientId = clientId ?? const Uuid().v4();
    _username = username ?? '';
    _password = password ?? '';
    _useWebSocket = useWebSocket;
    _useWss = useWss;
    _wsPath = wsPath;
    _keepAlive = keepAlive;

    _state = ConnectionState.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      // 创建客户端
      // 注意: mqtt_client 库的 WebSocket 路径通常使用默认值 /mqtt
      // _wsPath 保留以备将来扩展
      _client = MqttServerClient.withPort(host, _clientId, port);

      if (_useWebSocket) {
        _client!.useWebSocket = true;
        _client!.websocketProtocols =
            MqttClientConstants.protocolsSingleDefault;
        if (_useWss) {
          _client!.secure = true;
        }
      }

      _client!.logging(on: false);
      _client!.keepAlivePeriod = _keepAlive;
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.onUnsubscribed = _onUnsubscribed;
      _client!.pongCallback = _onPong;

      // 设置连接消息
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

      if (_username.isNotEmpty) {
        connMessage.authenticateAs(_username, _password);
      }

      _client!.connectionMessage = connMessage;

      // 连接
      await _client!.connect();

      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        _state = ConnectionState.connected;
        _statistics.start();
        _errorMessage = null;

        // 监听消息
        _client!.updates?.listen(_onMessage);

        notifyListeners();
        return true;
      } else {
        _state = ConnectionState.error;
        _errorMessage = '连接失败: ${_client!.connectionStatus?.returnCode}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state = ConnectionState.error;
      _errorMessage = '连接失败: $e';
      _client?.disconnect();
      _client = null;
      notifyListeners();
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _client?.disconnect();
    _client = null;
    _subscriptions.clear();
    _state = ConnectionState.disconnected;
    notifyListeners();
  }

  /// 订阅主题
  bool subscribe(String topic, {MqttQos qos = MqttQos.atMostOnce}) {
    if (!isConnected || _client == null) {
      _errorMessage = '未连接到服务器';
      notifyListeners();
      return false;
    }

    try {
      _client!.subscribe(topic, qos);

      final subscription = MqttSubscription(topic: topic, qos: qos);
      if (!_subscriptions.contains(subscription)) {
        _subscriptions.add(subscription);
      }

      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '订阅失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 取消订阅
  bool unsubscribe(String topic) {
    if (!isConnected || _client == null) {
      _errorMessage = '未连接到服务器';
      notifyListeners();
      return false;
    }

    try {
      _client!.unsubscribe(topic);
      _subscriptions.removeWhere((s) => s.topic == topic);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '取消订阅失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 发布消息
  Future<bool> publish(
    String topic,
    Uint8List data, {
    MqttQos qos = MqttQos.atMostOnce,
    bool retain = false,
  }) async {
    if (!isConnected || _client == null) {
      _errorMessage = '未连接到服务器';
      notifyListeners();
      return false;
    }

    try {
      final builder = MqttClientPayloadBuilder();
      final buffer = Uint8Buffer()..addAll(data);
      builder.addBuffer(buffer);

      _client!.publishMessage(topic, qos, builder.payload!, retain: retain);

      _statistics.addSentData(data.length);

      final message = MessageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        data: data,
        direction: MessageDirection.sent,
        topic: topic,
        qos: qos.index,
      );
      _addMessage(message);

      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '发布失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 处理接收消息
  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    if (_isPaused) return;

    for (final message in messages) {
      final topic = message.topic;
      final payload = message.payload as MqttPublishMessage;
      final data = Uint8List.fromList(payload.payload.message);

      _statistics.addReceivedData(data.length);

      final messageData = MessageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        data: data,
        direction: MessageDirection.received,
        topic: topic,
        qos: payload.header?.qos.index,
      );
      _addMessage(messageData);
    }
    notifyListeners();
  }

  /// 连接成功回调
  void _onConnected() {
    _state = ConnectionState.connected;
    notifyListeners();
  }

  /// 断开连接回调
  void _onDisconnected() {
    _state = ConnectionState.disconnected;
    _subscriptions.clear();
    notifyListeners();
  }

  /// 订阅成功回调
  void _onSubscribed(String topic) {
    // 已在subscribe方法中处理
  }

  /// 取消订阅回调
  void _onUnsubscribed(String? topic) {
    // 已在unsubscribe方法中处理
  }

  /// Pong回调
  void _onPong() {
    // Keep alive pong received
  }

  /// 添加消息（限制数量）
  void _addMessage(MessageData message) {
    _messages.add(message);
    if (_messages.length > AppConstants.maxMessageHistory) {
      _messages.removeAt(0);
    }
  }

  /// 暂停接收
  void pause() {
    _isPaused = true;
    notifyListeners();
  }

  /// 继续接收
  void resume() {
    _isPaused = false;
    notifyListeners();
  }

  /// 清空消息
  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  /// 重置统计信息
  void resetStatistics() {
    _statistics.reset();
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 获取QoS显示名称
  static String getQosName(MqttQos qos) {
    switch (qos) {
      case MqttQos.atMostOnce:
        return 'QoS 0 (最多一次)';
      case MqttQos.atLeastOnce:
        return 'QoS 1 (至少一次)';
      case MqttQos.exactlyOnce:
        return 'QoS 2 (恰好一次)';
      default:
        return 'QoS 0';
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
