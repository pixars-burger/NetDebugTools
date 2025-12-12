import 'package:flutter/material.dart';
import 'tcp_client/tcp_client_page.dart';
import 'tcp_server/tcp_server_page.dart';
import 'udp/udp_page.dart';
import 'mqtt/mqtt_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    TcpServerPage(),
    TcpClientPage(),
    UdpPage(),
    MqttPage(),
  ];

  final List<String> _titles = const [
    'TCP Server',
    'TCP Client',
    'UDP',
    'MQTT',
  ];

  final List<IconData> _icons = const [
    Icons.dns,
    Icons.computer,
    Icons.swap_horiz,
    Icons.cloud,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        centerTitle: true,
        elevation: 1,
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: List.generate(
          _titles.length,
          (index) => NavigationDestination(
            icon: Icon(_icons[index]),
            label: _titles[index],
          ),
        ),
      ),
    );
  }
}
