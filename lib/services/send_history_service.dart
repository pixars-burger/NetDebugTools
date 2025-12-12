import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// 发送历史服务（持久化存储）
class SendHistoryService {
  static SendHistoryService? _instance;
  SharedPreferences? _prefs;

  SendHistoryService._();

  static SendHistoryService get instance {
    _instance ??= SendHistoryService._();
    return _instance!;
  }

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 获取发送历史
  List<String> getHistory(String key) {
    if (_prefs == null) return [];

    final json = _prefs!.getString(key);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  /// 添加发送历史
  Future<void> addHistory(String key, String value) async {
    if (_prefs == null) return;
    if (value.isEmpty) return;

    final history = getHistory(key);

    // 如果已存在，移到最前面
    history.remove(value);
    history.insert(0, value);

    // 限制数量
    while (history.length > AppConstants.maxSendHistory) {
      history.removeLast();
    }

    await _prefs!.setString(key, jsonEncode(history));
  }

  /// 清空发送历史
  Future<void> clearHistory(String key) async {
    if (_prefs == null) return;
    await _prefs!.remove(key);
  }

  /// 获取TCP Client发送历史
  List<String> get tcpClientHistory =>
      getHistory(AppConstants.prefTcpClientHistory);

  /// 添加TCP Client发送历史
  Future<void> addTcpClientHistory(String value) async {
    await addHistory(AppConstants.prefTcpClientHistory, value);
  }

  /// 清空TCP Client发送历史
  Future<void> clearTcpClientHistory() async {
    await clearHistory(AppConstants.prefTcpClientHistory);
  }

  /// 获取TCP Server发送历史
  List<String> get tcpServerHistory =>
      getHistory(AppConstants.prefTcpServerHistory);

  /// 添加TCP Server发送历史
  Future<void> addTcpServerHistory(String value) async {
    await addHistory(AppConstants.prefTcpServerHistory, value);
  }

  /// 清空TCP Server发送历史
  Future<void> clearTcpServerHistory() async {
    await clearHistory(AppConstants.prefTcpServerHistory);
  }

  /// 获取UDP发送历史
  List<String> get udpHistory => getHistory(AppConstants.prefUdpHistory);

  /// 添加UDP发送历史
  Future<void> addUdpHistory(String value) async {
    await addHistory(AppConstants.prefUdpHistory, value);
  }

  /// 清空UDP发送历史
  Future<void> clearUdpHistory() async {
    await clearHistory(AppConstants.prefUdpHistory);
  }

  /// 获取MQTT发送历史
  List<String> get mqttHistory => getHistory(AppConstants.prefMqttHistory);

  /// 添加MQTT发送历史
  Future<void> addMqttHistory(String value) async {
    await addHistory(AppConstants.prefMqttHistory, value);
  }

  /// 清空MQTT发送历史
  Future<void> clearMqttHistory() async {
    await clearHistory(AppConstants.prefMqttHistory);
  }

  /// 获取MQTT Topic历史
  List<String> get mqttTopicHistory =>
      getHistory(AppConstants.prefMqttTopicHistory);

  /// 添加MQTT Topic历史
  Future<void> addMqttTopicHistory(String value) async {
    await addHistory(AppConstants.prefMqttTopicHistory, value);
  }

  /// 清空MQTT Topic历史
  Future<void> clearMqttTopicHistory() async {
    await clearHistory(AppConstants.prefMqttTopicHistory);
  }

  // ========== MQTT连接配置持久化 ==========

  /// 获取字符串值
  String? getString(String key) {
    return _prefs?.getString(key);
  }

  /// 设置字符串值
  Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  /// 获取整数值
  int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  /// 设置整数值
  Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  /// 获取布尔值
  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  /// 设置布尔值
  Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  /// 保存MQTT连接配置
  Future<void> saveMqttConfig({
    required String host,
    required int port,
    String? username,
    required bool useWebSocket,
    required bool useWss,
    String? wsPath,
  }) async {
    await setString(AppConstants.prefMqttHost, host);
    await setInt(AppConstants.prefMqttPort, port);
    if (username != null && username.isNotEmpty) {
      await setString(AppConstants.prefMqttUsername, username);
    }
    await setBool(AppConstants.prefMqttUseWebSocket, useWebSocket);
    await setBool(AppConstants.prefMqttUseWss, useWss);
    if (wsPath != null && wsPath.isNotEmpty) {
      await setString(AppConstants.prefMqttWsPath, wsPath);
    }
  }

  /// 获取MQTT连接配置
  Map<String, dynamic> getMqttConfig() {
    return {
      'host': getString(AppConstants.prefMqttHost) ?? 'broker.emqx.io',
      'port': getInt(AppConstants.prefMqttPort) ?? 1883,
      'username': getString(AppConstants.prefMqttUsername) ?? '',
      'useWebSocket': getBool(AppConstants.prefMqttUseWebSocket) ?? false,
      'useWss': getBool(AppConstants.prefMqttUseWss) ?? false,
      'wsPath': getString(AppConstants.prefMqttWsPath) ?? '/mqtt',
    };
  }

  /// 保存最后使用的订阅主题
  Future<void> saveLastSubTopic(String topic) async {
    await setString(AppConstants.prefMqttLastSubTopic, topic);
    await addMqttTopicHistory(topic);
  }

  /// 获取最后使用的订阅主题
  String getLastSubTopic() {
    return getString(AppConstants.prefMqttLastSubTopic) ?? 'test/topic';
  }

  /// 保存最后使用的发布主题
  Future<void> saveLastPubTopic(String topic) async {
    await setString(AppConstants.prefMqttLastPubTopic, topic);
    await addMqttTopicHistory(topic);
  }

  /// 获取最后使用的发布主题
  String getLastPubTopic() {
    return getString(AppConstants.prefMqttLastPubTopic) ?? 'test/topic';
  }
}
