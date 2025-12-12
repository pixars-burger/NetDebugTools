import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../utils/constants.dart';

/// TCP客户端信息
class TcpClientInfo {
  final String id;
  final Socket socket;
  final String address;
  final int port;
  final DateTime connectedAt;
  final Statistics statistics;
  StreamSubscription? subscription;

  TcpClientInfo({
    required this.id,
    required this.socket,
    required this.address,
    required this.port,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now(),
       statistics = Statistics()..start();

  String get displayAddress => '$address:$port';

  ConnectionInfo toConnectionInfo({bool isConnected = true}) {
    return ConnectionInfo(
      id: id,
      remoteAddress: address,
      remotePort: port,
      connectedAt: connectedAt,
      disconnectedAt: isConnected ? null : DateTime.now(),
      isConnected: isConnected,
    );
  }
}

/// TCP服务器服务
class TcpServerService extends ChangeNotifier {
  ServerSocket? _serverSocket;
  ServerState _state = ServerState.stopped;
  final Map<String, TcpClientInfo> _clients = {};
  final List<ConnectionInfo> _connectionHistory = [];
  final List<MessageData> _messages = [];
  final Statistics _statistics = Statistics();
  String? _errorMessage;
  bool _isPaused = false;

  String _bindAddress = '0.0.0.0';
  int _port = AppConstants.defaultTcpPort;

  // Getters
  ServerState get state => _state;
  Map<String, TcpClientInfo> get clients => Map.unmodifiable(_clients);
  List<TcpClientInfo> get clientList => _clients.values.toList();
  List<ConnectionInfo> get connectionHistory =>
      List.unmodifiable(_connectionHistory);
  List<MessageData> get messages => List.unmodifiable(_messages);
  Statistics get statistics => _statistics;
  String? get errorMessage => _errorMessage;
  bool get isPaused => _isPaused;
  bool get isRunning => _state == ServerState.running;
  String get bindAddress => _bindAddress;
  int get port => _port;
  int get clientCount => _clients.length;

  /// 启动服务器
  Future<bool> start(String address, int port) async {
    if (_state == ServerState.starting || _state == ServerState.running) {
      return false;
    }

    _bindAddress = address;
    _port = port;
    _state = ServerState.starting;
    _errorMessage = null;
    notifyListeners();

    try {
      _serverSocket = await ServerSocket.bind(address, port, shared: false);

      _state = ServerState.running;
      _statistics.start();
      _errorMessage = null;

      // 监听连接
      _serverSocket!.listen(
        _onClientConnect,
        onError: _onServerError,
        onDone: _onServerDone,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _state = ServerState.error;
      _errorMessage = '启动服务器失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 停止服务器
  Future<void> stop() async {
    // 断开所有客户端
    for (final client in _clients.values.toList()) {
      await _disconnectClient(client.id, addToHistory: true);
    }
    _clients.clear();

    try {
      await _serverSocket?.close();
    } catch (e) {
      // 忽略关闭错误
    }

    _serverSocket = null;
    _state = ServerState.stopped;
    notifyListeners();
  }

  /// 处理新客户端连接
  void _onClientConnect(Socket socket) {
    if (_clients.length >= AppConstants.maxTcpClients) {
      socket.close();
      return;
    }

    final id =
        '${socket.remoteAddress.address}:${socket.remotePort}_${DateTime.now().millisecondsSinceEpoch}';
    final client = TcpClientInfo(
      id: id,
      socket: socket,
      address: socket.remoteAddress.address,
      port: socket.remotePort,
    );

    _clients[id] = client;

    // 监听客户端数据
    client.subscription = socket.listen(
      (data) => _onClientData(id, Uint8List.fromList(data)),
      onError: (error) => _onClientError(id, error),
      onDone: () => _onClientDone(id),
      cancelOnError: false,
    );

    notifyListeners();
  }

  /// 处理客户端数据
  void _onClientData(String clientId, Uint8List data) {
    if (_isPaused) return;

    final client = _clients[clientId];
    if (client == null) return;

    client.statistics.addReceivedData(data.length);
    _statistics.addReceivedData(data.length);

    final message = MessageData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      data: data,
      direction: MessageDirection.received,
      source: client.displayAddress,
    );
    _addMessage(message);
    notifyListeners();
  }

  /// 处理客户端错误
  void _onClientError(String clientId, dynamic error) {
    _disconnectClient(clientId, addToHistory: true);
  }

  /// 处理客户端断开
  void _onClientDone(String clientId) {
    _disconnectClient(clientId, addToHistory: true);
  }

  /// 断开指定客户端
  Future<void> _disconnectClient(
    String clientId, {
    bool addToHistory = false,
  }) async {
    final client = _clients.remove(clientId);
    if (client == null) return;

    await client.subscription?.cancel();
    try {
      await client.socket.close();
    } catch (e) {
      // 忽略关闭错误
    }

    if (addToHistory) {
      _addConnectionHistory(client.toConnectionInfo(isConnected: false));
    }

    notifyListeners();
  }

  /// 手动断开客户端
  Future<void> disconnectClient(String clientId) async {
    await _disconnectClient(clientId, addToHistory: true);
  }

  /// 向指定客户端发送数据（单播）
  Future<bool> sendToClient(String clientId, Uint8List data) async {
    final client = _clients[clientId];
    if (client == null) {
      _errorMessage = '客户端不存在';
      notifyListeners();
      return false;
    }

    try {
      client.socket.add(data);
      await client.socket.flush();

      client.statistics.addSentData(data.length);
      _statistics.addSentData(data.length);

      final message = MessageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        data: data,
        direction: MessageDirection.sent,
        source: client.displayAddress,
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

  /// 向所有客户端发送数据（广播）
  Future<int> broadcast(Uint8List data) async {
    int successCount = 0;
    final failedClients = <String>[];

    for (final client in _clients.values) {
      try {
        client.socket.add(data);
        await client.socket.flush();

        client.statistics.addSentData(data.length);
        _statistics.addSentData(data.length);
        successCount++;
      } catch (e) {
        failedClients.add(client.id);
      }
    }

    if (successCount > 0) {
      final message = MessageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        data: data,
        direction: MessageDirection.sent,
        source: '广播 ($successCount/${_clients.length})',
      );
      _addMessage(message);
    }

    // 移除发送失败的客户端
    for (final clientId in failedClients) {
      await _disconnectClient(clientId, addToHistory: true);
    }

    _errorMessage = failedClients.isEmpty ? null : '部分发送失败';
    notifyListeners();
    return successCount;
  }

  /// 处理服务器错误
  void _onServerError(dynamic error) {
    _errorMessage = '服务器错误: $error';
    _state = ServerState.error;
    notifyListeners();
  }

  /// 处理服务器关闭
  void _onServerDone() {
    _state = ServerState.stopped;
    _serverSocket = null;
    notifyListeners();
  }

  /// 添加消息（限制数量）
  void _addMessage(MessageData message) {
    _messages.add(message);
    if (_messages.length > AppConstants.maxMessageHistory) {
      _messages.removeAt(0);
    }
  }

  /// 添加连接历史（限制数量）
  void _addConnectionHistory(ConnectionInfo info) {
    _connectionHistory.insert(0, info);
    if (_connectionHistory.length > AppConstants.maxConnectionHistory) {
      _connectionHistory.removeLast();
    }
  }

  /// 删除连接历史记录
  void removeConnectionHistory(String id) {
    _connectionHistory.removeWhere((info) => info.id == id);
    notifyListeners();
  }

  /// 清空连接历史
  void clearConnectionHistory() {
    _connectionHistory.clear();
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
    for (final client in _clients.values) {
      client.statistics.reset();
    }
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
