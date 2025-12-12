/// 连接信息模型
class ConnectionInfo {
  final String id;
  final String remoteAddress;
  final int remotePort;
  final String localAddress;
  final int localPort;
  final DateTime connectedAt;
  DateTime? disconnectedAt;
  bool isConnected;

  ConnectionInfo({
    required this.id,
    required this.remoteAddress,
    required this.remotePort,
    this.localAddress = '',
    this.localPort = 0,
    DateTime? connectedAt,
    this.disconnectedAt,
    this.isConnected = true,
  }) : connectedAt = connectedAt ?? DateTime.now();

  /// 获取连接时长（秒）
  Duration get connectionDuration {
    final endTime = disconnectedAt ?? DateTime.now();
    return endTime.difference(connectedAt);
  }

  /// 格式化连接时长
  String get formattedDuration {
    final duration = connectionDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// 获取显示地址
  String get displayAddress => '$remoteAddress:$remotePort';

  /// 复制并更新
  ConnectionInfo copyWith({
    String? id,
    String? remoteAddress,
    int? remotePort,
    String? localAddress,
    int? localPort,
    DateTime? connectedAt,
    DateTime? disconnectedAt,
    bool? isConnected,
  }) {
    return ConnectionInfo(
      id: id ?? this.id,
      remoteAddress: remoteAddress ?? this.remoteAddress,
      remotePort: remotePort ?? this.remotePort,
      localAddress: localAddress ?? this.localAddress,
      localPort: localPort ?? this.localPort,
      connectedAt: connectedAt ?? this.connectedAt,
      disconnectedAt: disconnectedAt ?? this.disconnectedAt,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  String toString() {
    return 'ConnectionInfo(id: $id, address: $displayAddress, connected: $isConnected)';
  }
}
