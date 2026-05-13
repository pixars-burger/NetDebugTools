import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_theme_controller.dart';
import '../pages/home_page.dart';
import 'app_providers.dart';

class NetDebugApp extends StatelessWidget {
  const NetDebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: appProviders,
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<AppThemeController?>(context);
    return MaterialApp(
      title: '网络调试助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: themeController?.themeMode ?? ThemeMode.system,
      home: const HomePage(),
    );
  }
}
