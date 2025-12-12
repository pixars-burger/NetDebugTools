import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../utils/constants.dart';

/// UDP服务
class UdpService extends ChangeNotifier {
  RawDatagramSocket? _socket;
  ConnectionState _state = ConnectionState.disconnected;
  final Statistics _statistics = Statistics();
  final List<MessageData> _messages = [];
  String? _errorMessage;
  bool _isPaused = false;

  int _localPort = AppConstants.defaultUdpPort;
  String _targetHost = '';
  int _targetPort = AppConstants.defaultUdpPort;

  // Getters
  ConnectionState get state => _state;
  Statistics get statistics => _statistics;
  List<MessageData> get messages => List.unmodifiable(_messages);
  String? get errorMessage => _errorMessage;
  bool get isPaused => _isPaused;
  bool get isActive => _state == ConnectionState.connected;
  int get localPort => _localPort;
  String get targetHost => _targetHost;
  int get targetPort => _targetPort;

  /// 启动UDP监听
  Future<bool> start(int localPort, String targetHost, int targetPort) async {
    if (_state == ConnectionState.connecting ||
        _state == ConnectionState.connected) {
      return false;
    }

    _localPort = localPort;
    _targetHost = targetHost;
    _targetPort = targetPort;
    _state = ConnectionState.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        localPort,
      );

      _state = ConnectionState.connected;
      _statistics.start();
      _errorMessage = null;

      // 监听数据
      _socket!.listen(_onEvent, onError: _onError, onDone: _onDone);

      notifyListeners();
      return true;
    } catch (e) {
      _state = ConnectionState.error;
      _errorMessage = '启动失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 停止UDP
  Future<void> stop() async {
    _socket?.close();
    _socket = null;
    _state = ConnectionState.disconnected;
    notifyListeners();
  }

  /// 发送数据
  Future<bool> send(Uint8List data, {String? host, int? port}) async {
    if (!isActive || _socket == null) {
      _errorMessage = 'UDP未启动';
      notifyListeners();
      return false;
    }

    final targetHost = host ?? _targetHost;
    final targetPort = port ?? _targetPort;

    if (targetHost.isEmpty) {
      _errorMessage = '请设置目标地址';
      notifyListeners();
      return false;
    }

    try {
      final address = InternetAddress.tryParse(targetHost);
      if (address == null) {
        // 尝试解析域名
        final addresses = await InternetAddress.lookup(targetHost);
        if (addresses.isEmpty) {
          _errorMessage = '无法解析地址: $targetHost';
          notifyListeners();
          return false;
        }
        final resolved = addresses.first;
        _socket!.send(data, resolved, targetPort);
      } else {
        _socket!.send(data, address, targetPort);
      }

      _statistics.addSentData(data.length);

      final message = MessageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        data: data,
        direction: MessageDirection.sent,
        source: '$targetHost:$targetPort',
      );
      _addMessage(message);

      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '发送失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 处理Socket事件
  void _onEvent(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket?.receive();
      if (datagram != null && !_isPaused) {
        _statistics.addReceivedData(datagram.data.length);

        final message = MessageData(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          data: Uint8List.fromList(datagram.data),
          direction: MessageDirection.received,
          source: '${datagram.address.address}:${datagram.port}',
        );
        _addMessage(message);
        notifyListeners();
      }
    }
  }

  /// 处理错误
  void _onError(dynamic error) {
    _errorMessage = '错误: $error';
    _state = ConnectionState.error;
    notifyListeners();
  }

  /// 处理关闭
  void _onDone() {
    _state = ConnectionState.disconnected;
    _socket = null;
    notifyListeners();
  }

  /// 添加消息（限制数量）
  void _addMessage(MessageData message) {
    _messages.add(message);
    if (_messages.length > AppConstants.maxMessageHistory) {
      _messages.removeAt(0);
    }
  }

  /// 更新目标地址
  void setTarget(String host, int port) {
    _targetHost = host;
    _targetPort = port;
    notifyListeners();
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

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
