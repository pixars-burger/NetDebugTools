/// 统计信息模型
class Statistics {
  int sentBytes;
  int receivedBytes;
  int sentPackets;
  int receivedPackets;
  DateTime? startTime;

  Statistics({
    this.sentBytes = 0,
    this.receivedBytes = 0,
    this.sentPackets = 0,
    this.receivedPackets = 0,
    this.startTime,
  });

  /// 获取连接时长
  Duration get connectionDuration {
    if (startTime == null) return Duration.zero;
    return DateTime.now().difference(startTime!);
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

  /// 格式化字节数
  String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// 获取格式化的发送字节数
  String get formattedSentBytes => formatBytes(sentBytes);

  /// 获取格式化的接收字节数
  String get formattedReceivedBytes => formatBytes(receivedBytes);

  /// 添加发送数据
  void addSentData(int bytes) {
    sentBytes += bytes;
    sentPackets++;
  }

  /// 添加接收数据
  void addReceivedData(int bytes) {
    receivedBytes += bytes;
    receivedPackets++;
  }

  /// 开始计时
  void start() {
    startTime = DateTime.now();
  }

  /// 重置统计信息
  void reset() {
    sentBytes = 0;
    receivedBytes = 0;
    sentPackets = 0;
    receivedPackets = 0;
    startTime = DateTime.now();
  }

  /// 复制
  Statistics copy() {
    return Statistics(
      sentBytes: sentBytes,
      receivedBytes: receivedBytes,
      sentPackets: sentPackets,
      receivedPackets: receivedPackets,
      startTime: startTime,
    );
  }

  @override
  String toString() {
    return 'Statistics(sent: $formattedSentBytes/$sentPackets pkts, received: $formattedReceivedBytes/$receivedPackets pkts, duration: $formattedDuration)';
  }
}
