import 'dart:convert';
import 'dart:typed_data';
import 'package:fast_gbk/fast_gbk.dart';
import '../models/message_data.dart';

/// 字符编码类型
enum CharEncoding { utf8, gbk, gb2312, ascii }

/// 数据格式转换工具
class DataConverter {
  /// 将字符串按指定格式和编码转换为字节数组
  static ConversionResult stringToBytes(
    String input,
    DataFormat format, [
    CharEncoding encoding = CharEncoding.utf8,
  ]) {
    try {
      switch (format) {
        case DataFormat.text:
        case DataFormat.json:
          return ConversionResult.success(
            Uint8List.fromList(_encodeString(input, encoding)),
          );
        case DataFormat.hex:
          return _hexToBytes(input);
        case DataFormat.base64:
          return _base64ToBytes(input);
        case DataFormat.binary:
          return _binaryToBytes(input);
      }
    } catch (e) {
      return ConversionResult.failure('转换失败: $e');
    }
  }

  /// 使用指定编码将字符串编码为字节
  static List<int> _encodeString(String input, CharEncoding encoding) {
    switch (encoding) {
      case CharEncoding.utf8:
        return utf8.encode(input);
      case CharEncoding.gbk:
      case CharEncoding.gb2312:
        return gbk.encode(input);
      case CharEncoding.ascii:
        return ascii.encode(input);
    }
  }

  /// 使用指定编码将字节解码为字符串
  static String _decodeBytes(List<int> bytes, CharEncoding encoding) {
    switch (encoding) {
      case CharEncoding.utf8:
        return utf8.decode(bytes, allowMalformed: true);
      case CharEncoding.gbk:
      case CharEncoding.gb2312:
        try {
          return gbk.decode(bytes);
        } catch (e) {
          return utf8.decode(bytes, allowMalformed: true);
        }
      case CharEncoding.ascii:
        return ascii.decode(bytes, allowInvalid: true);
    }
  }

  /// 将字节数组按指定格式和编码转换为字符串
  static String bytesToString(
    Uint8List bytes,
    DataFormat format, [
    CharEncoding encoding = CharEncoding.utf8,
  ]) {
    switch (format) {
      case DataFormat.text:
        return _decodeBytes(bytes, encoding);
      case DataFormat.hex:
        return _bytesToHex(bytes);
      case DataFormat.base64:
        return base64Encode(bytes);
      case DataFormat.binary:
        return _bytesToBinary(bytes);
      case DataFormat.json:
        try {
          final text = _decodeBytes(bytes, encoding);
          final decoded = jsonDecode(text);
          return const JsonEncoder.withIndent('  ').convert(decoded);
        } catch (e) {
          return _decodeBytes(bytes, encoding);
        }
    }
  }

  /// 十六进制字符串转字节数组
  static ConversionResult _hexToBytes(String hex) {
    // 移除空格和常见分隔符
    hex = hex.replaceAll(RegExp(r'[\s,\-:]'), '');

    // 移除可能的0x前缀
    hex = hex.replaceAll(RegExp(r'0[xX]'), '');

    if (hex.isEmpty) {
      return ConversionResult.success(Uint8List(0));
    }

    // 检查是否为有效的十六进制字符
    if (!RegExp(r'^[0-9A-Fa-f]+$').hasMatch(hex)) {
      return ConversionResult.failure('包含无效的十六进制字符');
    }

    // 如果长度为奇数，在前面补0
    if (hex.length % 2 != 0) {
      hex = '0$hex';
    }

    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return ConversionResult.success(bytes);
  }

  /// 字节数组转十六进制字符串
  static String _bytesToHex(Uint8List bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  /// Base64字符串转字节数组
  static ConversionResult _base64ToBytes(String base64Str) {
    // 移除空格和换行
    base64Str = base64Str.replaceAll(RegExp(r'\s'), '');

    if (base64Str.isEmpty) {
      return ConversionResult.success(Uint8List(0));
    }

    try {
      final bytes = base64Decode(base64Str);
      return ConversionResult.success(Uint8List.fromList(bytes));
    } catch (e) {
      return ConversionResult.failure('无效的Base64编码');
    }
  }

  /// 二进制字符串转字节数组
  static ConversionResult _binaryToBytes(String binary) {
    // 移除空格和常见分隔符
    binary = binary.replaceAll(RegExp(r'[\s,\-:]'), '');

    if (binary.isEmpty) {
      return ConversionResult.success(Uint8List(0));
    }

    // 检查是否只包含0和1
    if (!RegExp(r'^[01]+$').hasMatch(binary)) {
      return ConversionResult.failure('包含无效的二进制字符（只允许0和1）');
    }

    // 补齐到8的倍数
    final padding = (8 - binary.length % 8) % 8;
    binary = '0' * padding + binary;

    final bytes = Uint8List(binary.length ~/ 8);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(binary.substring(i * 8, i * 8 + 8), radix: 2);
    }

    return ConversionResult.success(bytes);
  }

  /// 字节数组转二进制字符串
  static String _bytesToBinary(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(2).padLeft(8, '0')).join(' ');
  }

  /// 获取格式的显示名称
  static String getFormatName(DataFormat format) {
    switch (format) {
      case DataFormat.text:
        return '文本';
      case DataFormat.hex:
        return 'Hex';
      case DataFormat.base64:
        return 'Base64';
      case DataFormat.binary:
        return '二进制';
      case DataFormat.json:
        return 'JSON';
    }
  }

  /// 获取编码名称
  static String getEncodingName(CharEncoding encoding) {
    switch (encoding) {
      case CharEncoding.utf8:
        return 'UTF-8';
      case CharEncoding.gbk:
        return 'GBK';
      case CharEncoding.gb2312:
        return 'GB2312';
      case CharEncoding.ascii:
        return 'ASCII';
    }
  }

  /// 获取所有格式列表
  static List<DataFormat> get allFormats => DataFormat.values;

  /// 获取所有编码列表
  static List<CharEncoding> get allEncodings => CharEncoding.values;
}

/// 转换结果
class ConversionResult {
  final bool isSuccess;
  final Uint8List? data;
  final String? error;

  ConversionResult._({required this.isSuccess, this.data, this.error});

  factory ConversionResult.success(Uint8List data) {
    return ConversionResult._(isSuccess: true, data: data);
  }

  factory ConversionResult.failure(String error) {
    return ConversionResult._(isSuccess: false, error: error);
  }
}
