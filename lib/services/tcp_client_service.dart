import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../utils/constants.dart';

/// TCP客户端服务
class TcpClientService extends ChangeNotifier {
  Socket? _socket;
  ConnectionState _state = ConnectionState.disconnected;
  final Statistics _statistics = Statistics();
  final List<MessageData> _messages = [];
  String? _errorMessage;
  bool _isPaused = false;
  StreamSubscription? _subscription;

  String _host = '';
  int _port = AppConstants.defaultTcpPort;

  // Getters
  ConnectionState get state => _state;
  Statistics get statistics => _statistics;
  List<MessageData> get messages => List.unmodifiable(_messages);
  String? get errorMessage => _errorMessage;
  bool get isPaused => _isPaused;
  bool get isConnected => _state == ConnectionState.connected;
  String get host => _host;
  int get port => _port;

  /// 连接到服务器
  Future<bool> connect(String host, int port) async {
    if (_state == ConnectionState.connecting ||
        _state == ConnectionState.connected) {
      return false;
    }

    _host = host;
    _port = port;
    _state = ConnectionState.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: AppConstants.connectionTimeout),
      );

      _state = ConnectionState.connected;
      _statistics.start();
      _errorMessage = null;

      // 监听数据
      _subscription = _socket!.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _state = ConnectionState.error;
      _errorMessage = '连接失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    try {
      await _socket?.close();
    } catch (e) {
      // 忽略关闭错误
    }

    _socket = null;
    _state = ConnectionState.disconnected;
    notifyListeners();
  }

  /// 发送数据
  Future<bool> send(Uint8List data) async {
    if (!isConnected || _socket == null) {
      _errorMessage = '未连接到服务器';
      notifyListeners();
      return false;
    }

    try {
      _socket!.add(data);
      await _socket!.flush();

      _statistics.addSentData(data.length);

      final message = MessageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        data: data,
        direction: MessageDirection.sent,
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

  /// 处理接收数据
  void _onData(Uint8List data) {
    if (_isPaused) return;

    _statistics.addReceivedData(data.length);

    final message = MessageData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      data: data,
      direction: MessageDirection.received,
    );
    _addMessage(message);
    notifyListeners();
  }

  /// 处理错误
  void _onError(dynamic error) {
    _errorMessage = '连接错误: $error';
    _state = ConnectionState.error;
    notifyListeners();
  }

  /// 处理连接关闭
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
    disconnect();
    super.dispose();
  }
}
