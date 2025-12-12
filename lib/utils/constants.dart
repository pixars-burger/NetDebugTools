/// 应用常量定义
class AppConstants {
  // 应用信息
  static const String appName = '网络调试助手';
  static const String appVersion = '1.0.0';

  // 网络配置
  static const int defaultTcpPort = 8080;
  static const int defaultUdpPort = 8081;
  static const int defaultMqttPort = 1883;
  static const int defaultMqttWsPort = 8083;
  static const int defaultMqttWssPort = 8084;

  static const int minPort = 1024;
  static const int maxPort = 65535;

  // 连接配置
  static const int connectionTimeout = 10; // 秒
  static const int receiveTimeout = 30; // 秒
  static const int bufferSize = 4096; // 字节

  // Ping配置
  static const int pingCount = 3;
  static const int pingTimeout = 6; // 秒

  // MQTT配置
  static const int mqttKeepAlive = 60; // 秒
  static const String defaultMqttWsPath = '/mqtt';

  // 历史记录配置
  static const int maxSendHistory = 10;
  static const int maxConnectionHistory = 100;
  static const int maxMessageHistory = 1000;

  // 客户端限制
  static const int maxTcpClients = 50;

  // SharedPreferences键
  static const String prefTcpClientHistory = 'tcp_client_send_history';
  static const String prefTcpServerHistory = 'tcp_server_send_history';
  static const String prefUdpHistory = 'udp_send_history';
  static const String prefMqttHistory = 'mqtt_send_history';

  // MQTT配置持久化键
  static const String prefMqttHost = 'mqtt_host';
  static const String prefMqttPort = 'mqtt_port';
  static const String prefMqttUsername = 'mqtt_username';
  static const String prefMqttUseWebSocket = 'mqtt_use_websocket';
  static const String prefMqttUseWss = 'mqtt_use_wss';
  static const String prefMqttWsPath = 'mqtt_ws_path';
  static const String prefMqttTopicHistory = 'mqtt_topic_history';
  static const String prefMqttLastSubTopic = 'mqtt_last_sub_topic';
  static const String prefMqttLastPubTopic = 'mqtt_last_pub_topic';
}

/// 连接状态
enum ConnectionState {
  disconnected, // 已断开
  connecting, // 连接中
  connected, // 已连接
  error, // 错误
}

/// 服务器状态
enum ServerState {
  stopped, // 已停止
  starting, // 启动中
  running, // 运行中
  error, // 错误
}
