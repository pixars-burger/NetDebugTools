import 'package:flutter/material.dart';
import 'app/app.dart';
import 'services/send_history_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SendHistoryService.instance.init();

  runApp(const NetDebugApp());
}
