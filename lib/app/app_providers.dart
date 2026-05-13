import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/theme/app_theme_controller.dart';
import '../services/mqtt_service.dart';
import '../services/tcp_client_service.dart';
import '../services/tcp_server_service.dart';
import '../services/udp_service.dart';

final List<SingleChildWidget> appProviders = [
  ChangeNotifierProvider(create: (_) => AppThemeController()),
  ChangeNotifierProvider(create: (_) => TcpClientService()),
  ChangeNotifierProvider(create: (_) => TcpServerService()),
  ChangeNotifierProvider(create: (_) => UdpService()),
  ChangeNotifierProvider(create: (_) => MqttService()),
];
