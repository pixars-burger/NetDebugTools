import 'dart:typed_data';

/// 消息方向
enum MessageDirection {
  sent, // 发送
  received, // 接收
}

/// 数据格式
enum DataFormat {
  text, // 文本 (UTF-8)
  hex, // 十六进制
  base64, // Base64
  binary, // 二进制
  json, // JSON格式
}

/// 消息数据模型
class MessageData {
  final String id;
  final Uint8List data;
  final MessageDirection direction;
  final DateTime timestamp;
  final String? source; // 消息来源（用于TCP Server显示客户端信息）
  final String? topic; // MQTT主题
  final int? qos; // MQTT QoS级别

  MessageData({
    required this.id,
    required this.data,
    required this.direction,
    DateTime? timestamp,
    this.source,
    this.topic,
    this.qos,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 获取数据长度
  int get length => data.length;

  /// 是否为发送消息
  bool get isSent => direction == MessageDirection.sent;

  /// 是否为接收消息
  bool get isReceived => direction == MessageDirection.received;

  /// 转换为指定格式的字符串
  String toFormattedString(DataFormat format) {
    switch (format) {
      case DataFormat.text:
        try {
          return String.fromCharCodes(data);
        } catch (e) {
          return '[无法解码为文本]';
        }
      case DataFormat.hex:
        return data
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ');
      case DataFormat.base64:
        return _toBase64(data);
      case DataFormat.binary:
        return data.map((b) => b.toRadixString(2).padLeft(8, '0')).join(' ');
      case DataFormat.json:
        try {
          final text = String.fromCharCodes(data);
          // 尝试解析并格式化JSON
          final dynamic decoded = _parseJson(text);
          return _formatJson(decoded);
        } catch (e) {
          return '[无效的JSON格式]';
        }
    }
  }

  /// 解析JSON字符串
  dynamic _parseJson(String text) {
    // 简单JSON解析
    text = text.trim();
    if (text.startsWith('{') || text.startsWith('[')) {
      return _parseJsonValue(text);
    }
    throw FormatException('Not a valid JSON');
  }

  /// 解析JSON值
  dynamic _parseJsonValue(String text) {
    text = text.trim();
    if (text.isEmpty) throw FormatException('Empty JSON');

    if (text.startsWith('{')) {
      return _parseJsonObject(text);
    } else if (text.startsWith('[')) {
      return _parseJsonArray(text);
    } else if (text.startsWith('"')) {
      return _parseJsonString(text);
    } else if (text == 'true') {
      return true;
    } else if (text == 'false') {
      return false;
    } else if (text == 'null') {
      return null;
    } else {
      return num.tryParse(text) ?? text;
    }
  }

  Map<String, dynamic> _parseJsonObject(String text) {
    // 使用dart:convert进行解析
    final result = <String, dynamic>{};
    try {
      int depth = 0;
      int start = 1;
      String? currentKey;
      bool inString = false;
      bool escaped = false;

      for (int i = 1; i < text.length - 1; i++) {
        final char = text[i];
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == '\\') {
          escaped = true;
          continue;
        }
        if (char == '"') {
          inString = !inString;
          continue;
        }
        if (inString) continue;

        if (char == '{' || char == '[') depth++;
        if (char == '}' || char == ']') depth--;

        if (depth == 0 && char == ':' && currentKey == null) {
          currentKey = _parseJsonString(text.substring(start, i).trim());
          start = i + 1;
        }
        if (depth == 0 && (char == ',' || i == text.length - 2)) {
          final valueText = text
              .substring(start, char == ',' ? i : i + 1)
              .trim();
          if (currentKey != null && valueText.isNotEmpty) {
            result[currentKey] = _parseJsonValue(valueText);
          }
          currentKey = null;
          start = i + 1;
        }
      }
      return result;
    } catch (e) {
      return result;
    }
  }

  List<dynamic> _parseJsonArray(String text) {
    final result = <dynamic>[];
    try {
      int depth = 0;
      int start = 1;
      bool inString = false;
      bool escaped = false;

      for (int i = 1; i < text.length - 1; i++) {
        final char = text[i];
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == '\\') {
          escaped = true;
          continue;
        }
        if (char == '"') {
          inString = !inString;
          continue;
        }
        if (inString) continue;

        if (char == '{' || char == '[') depth++;
        if (char == '}' || char == ']') depth--;

        if (depth == 0 && (char == ',' || i == text.length - 2)) {
          final valueText = text
              .substring(start, char == ',' ? i : i + 1)
              .trim();
          if (valueText.isNotEmpty) {
            result.add(_parseJsonValue(valueText));
          }
          start = i + 1;
        }
      }
      return result;
    } catch (e) {
      return result;
    }
  }

  String _parseJsonString(String text) {
    text = text.trim();
    if (text.startsWith('"') && text.endsWith('"')) {
      return text
          .substring(1, text.length - 1)
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', '\\')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\r', '\r')
          .replaceAll(r'\t', '\t');
    }
    return text;
  }

  /// 格式化JSON为美观的字符串
  String _formatJson(dynamic value, [int indent = 0]) {
    final spaces = '  ' * indent;
    final nextSpaces = '  ' * (indent + 1);

    if (value == null) return 'null';
    if (value is bool) return value.toString();
    if (value is num) return value.toString();
    if (value is String) return '"$value"';

    if (value is List) {
      if (value.isEmpty) return '[]';
      final items = value
          .map((e) => '$nextSpaces${_formatJson(e, indent + 1)}')
          .join(',\n');
      return '[\n$items\n$spaces]';
    }

    if (value is Map) {
      if (value.isEmpty) return '{}';
      final items = value.entries
          .map(
            (e) => '$nextSpaces"${e.key}": ${_formatJson(e.value, indent + 1)}',
          )
          .join(',\n');
      return '{\n$items\n$spaces}';
    }

    return value.toString();
  }

  String _toBase64(Uint8List bytes) {
    const base64Chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buffer = StringBuffer();

    for (var i = 0; i < bytes.length; i += 3) {
      final b1 = bytes[i];
      final b2 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b3 = i + 2 < bytes.length ? bytes[i + 2] : 0;

      buffer.write(base64Chars[(b1 >> 2) & 0x3F]);
      buffer.write(base64Chars[((b1 << 4) | (b2 >> 4)) & 0x3F]);

      if (i + 1 < bytes.length) {
        buffer.write(base64Chars[((b2 << 2) | (b3 >> 6)) & 0x3F]);
      } else {
        buffer.write('=');
      }

      if (i + 2 < bytes.length) {
        buffer.write(base64Chars[b3 & 0x3F]);
      } else {
        buffer.write('=');
      }
    }

    return buffer.toString();
  }

  @override
  String toString() {
    return 'MessageData(id: $id, direction: $direction, length: $length)';
  }
}

/// 错误消息
class ErrorMessage {
  final String message;
  final DateTime timestamp;

  ErrorMessage({required this.message, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}
