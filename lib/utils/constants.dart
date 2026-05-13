class AppConstants {
  static const String appName = '网络调试助手';
  static const String appVersion = '1.0.0';

  static const int defaultTcpPort = 8080;
  static const int defaultUdpPort = 8081;
  static const int defaultMqttPort = 1883;
  static const int defaultMqttWsPort = 8083;
  static const int defaultMqttWssPort = 8084;
  static const String defaultRtspUrl = 'rtsp://';

  static const int minPort = 1024;
  static const int minBindablePort = 1;
  static const int maxPort = 65535;

  static const int connectionTimeout = 10;
  static const int receiveTimeout = 30;
  static const int bufferSize = 4096;

  static const int pingCount = 3;
  static const int pingTimeout = 6;

  // Use a shorter interval so brokers that idle-timeout around 30s keep the session.
  static const int mqttKeepAlive = 20;
  static const String defaultMqttWsPath = '/mqtt';

  static const int maxSendHistory = 10;
  static const int maxConnectionHistory = 100;
  static const int maxMessageHistory = 1000;

  static const int maxTcpClients = 50;

  static const String prefTcpClientHistory = 'tcp_client_send_history';
  static const String prefTcpServerHistory = 'tcp_server_send_history';
  static const String prefUdpHistory = 'udp_send_history';
  static const String prefMqttHistory = 'mqtt_send_history';
  static const String prefRtspHistory = 'rtsp_history';

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

enum ConnectionState { disconnected, connecting, connected, error }

enum ServerState { stopped, starting, running, error }
