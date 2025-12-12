import 'dart:io';
import '../utils/constants.dart';

/// 网络工具服务
class NetworkToolService {
  /// 获取本机所有可用的IPv4地址
  static Future<List<NetworkInterfaceInfo>> getLocalIPs() async {
    final result = <NetworkInterfaceInfo>[];

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            result.add(
              NetworkInterfaceInfo(name: interface.name, address: addr.address),
            );
          }
        }
      }
    } catch (e) {
      // 获取失败时返回空列表
    }

    // 如果没有找到任何IP，添加通配地址
    if (result.isEmpty) {
      result.add(NetworkInterfaceInfo(name: '所有接口', address: '0.0.0.0'));
    }

    return result;
  }

  /// 执行Ping操作
  static Future<PingResult> ping(
    String host, {
    int count = AppConstants.pingCount,
    int timeout = AppConstants.pingTimeout,
  }) async {
    try {
      // 使用系统ping命令
      final ProcessResult result;

      if (Platform.isAndroid || Platform.isLinux) {
        // Android/Linux: ping -c count -W timeout host
        result = await Process.run('ping', [
          '-c',
          count.toString(),
          '-W',
          timeout.toString(),
          host,
        ]);
      } else if (Platform.isWindows) {
        // Windows: ping -n count -w timeout*1000 host
        result = await Process.run('ping', [
          '-n',
          count.toString(),
          '-w',
          (timeout * 1000).toString(),
          host,
        ]);
      } else if (Platform.isIOS || Platform.isMacOS) {
        // iOS/macOS: ping -c count -t timeout host
        result = await Process.run('ping', [
          '-c',
          count.toString(),
          '-t',
          timeout.toString(),
          host,
        ]);
      } else {
        return PingResult.failure('不支持的平台');
      }

      final output = result.stdout.toString();
      final exitCode = result.exitCode;

      if (exitCode == 0) {
        // 解析ping结果
        return _parsePingOutput(output, host);
      } else {
        // Ping失败
        final errorOutput = result.stderr.toString();
        if (errorOutput.isNotEmpty) {
          return PingResult.failure('Ping失败: $errorOutput');
        }
        return PingResult.failure('无法访问主机: $host');
      }
    } catch (e) {
      return PingResult.failure('Ping执行错误: $e');
    }
  }

  /// 解析Ping输出
  static PingResult _parsePingOutput(String output, String host) {
    try {
      // 尝试解析延迟时间
      final times = <double>[];

      // 匹配不同格式的延迟时间
      // Linux/Android: time=xx.x ms
      // Windows: 时间=xxms 或 time=xxms
      // macOS: time=xx.xxx ms
      final timeRegex = RegExp(
        r'time[=<]?(\d+\.?\d*)\s*ms',
        caseSensitive: false,
      );
      final matches = timeRegex.allMatches(output);

      for (final match in matches) {
        final timeStr = match.group(1);
        if (timeStr != null) {
          times.add(double.parse(timeStr));
        }
      }

      if (times.isEmpty) {
        // 尝试Windows中文格式
        final cnTimeRegex = RegExp(r'时间[=<]?(\d+)\s*ms', caseSensitive: false);
        final cnMatches = cnTimeRegex.allMatches(output);
        for (final match in cnMatches) {
          final timeStr = match.group(1);
          if (timeStr != null) {
            times.add(double.parse(timeStr));
          }
        }
      }

      // 解析丢包率
      int packetLoss = 0;
      final lossRegex = RegExp(
        r'(\d+)%\s*(packet\s*)?loss',
        caseSensitive: false,
      );
      final lossMatch = lossRegex.firstMatch(output);
      if (lossMatch != null) {
        packetLoss = int.parse(lossMatch.group(1)!);
      } else {
        // 尝试中文格式
        final cnLossRegex = RegExp(r'丢失\s*=\s*(\d+)');
        final cnLossMatch = cnLossRegex.firstMatch(output);
        if (cnLossMatch != null) {
          final sent = RegExp(r'已发送\s*=\s*(\d+)').firstMatch(output);
          final lost = int.parse(cnLossMatch.group(1)!);
          if (sent != null) {
            final sentCount = int.parse(sent.group(1)!);
            packetLoss = (lost * 100 / sentCount).round();
          }
        }
      }

      if (times.isNotEmpty) {
        final avgTime = times.reduce((a, b) => a + b) / times.length;
        final minTime = times.reduce((a, b) => a < b ? a : b);
        final maxTime = times.reduce((a, b) => a > b ? a : b);

        return PingResult.success(
          host: host,
          avgTime: avgTime,
          minTime: minTime,
          maxTime: maxTime,
          packetLoss: packetLoss,
          received: times.length,
          rawOutput: output,
        );
      } else {
        return PingResult.success(
          host: host,
          avgTime: 0,
          minTime: 0,
          maxTime: 0,
          packetLoss: 100,
          received: 0,
          rawOutput: output,
        );
      }
    } catch (e) {
      return PingResult.failure('解析Ping结果失败: $e');
    }
  }

  /// 检查端口是否在有效范围内
  static bool isValidPort(int port) {
    return port >= AppConstants.minPort && port <= AppConstants.maxPort;
  }

  /// 检查IP地址格式是否有效
  static bool isValidIpAddress(String ip) {
    try {
      InternetAddress(ip);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 检查主机名是否有效（IP或域名）
  static bool isValidHost(String host) {
    if (host.isEmpty) return false;

    // 检查是否为有效IP
    if (isValidIpAddress(host)) return true;

    // 检查是否为有效域名格式
    final domainRegex = RegExp(
      r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
    );
    return domainRegex.hasMatch(host);
  }
}

/// 网络接口信息
class NetworkInterfaceInfo {
  final String name;
  final String address;

  NetworkInterfaceInfo({required this.name, required this.address});

  @override
  String toString() => '$name ($address)';
}

/// Ping结果
class PingResult {
  final bool isSuccess;
  final String? host;
  final double? avgTime;
  final double? minTime;
  final double? maxTime;
  final int? packetLoss;
  final int? received;
  final String? rawOutput;
  final String? error;

  PingResult._({
    required this.isSuccess,
    this.host,
    this.avgTime,
    this.minTime,
    this.maxTime,
    this.packetLoss,
    this.received,
    this.rawOutput,
    this.error,
  });

  factory PingResult.success({
    required String host,
    required double avgTime,
    required double minTime,
    required double maxTime,
    required int packetLoss,
    required int received,
    String? rawOutput,
  }) {
    return PingResult._(
      isSuccess: true,
      host: host,
      avgTime: avgTime,
      minTime: minTime,
      maxTime: maxTime,
      packetLoss: packetLoss,
      received: received,
      rawOutput: rawOutput,
    );
  }

  factory PingResult.failure(String error) {
    return PingResult._(isSuccess: false, error: error);
  }

  /// 获取格式化的结果描述
  String get summary {
    if (!isSuccess) {
      return error ?? '未知错误';
    }

    if (received == 0) {
      return '$host: 请求超时 (丢包率: 100%)';
    }

    return '$host: 延迟 ${avgTime?.toStringAsFixed(1)}ms '
        '(min: ${minTime?.toStringAsFixed(1)}ms, max: ${maxTime?.toStringAsFixed(1)}ms), '
        '丢包率: $packetLoss%';
  }
}
