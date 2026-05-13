import 'package:flutter/material.dart';
import 'mqtt/mqtt_page.dart';
import 'rtsp/rtsp_page.dart';
import 'tcp_client/tcp_client_page.dart';
import 'tcp_server/tcp_server_page.dart';
import 'udp/udp_page.dart';

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
    RtspPage(),
  ];

  final List<String> _titles = const [
    'TCP Server',
    'TCP Client',
    'UDP',
    'MQTT',
    'RTSP',
  ];

  final List<IconData> _icons = const [
    Icons.dns_rounded,
    Icons.computer_rounded,
    Icons.swap_horiz_rounded,
    Icons.cloud_queue_rounded,
    Icons.videocam_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final useRail = constraints.maxWidth >= 700 && isLandscape;
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        final keyboardVisible = bottomInset > 0;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          extendBody: true,
          body: SafeArea(
            top: true,
            bottom: !useRail,
            child: _buildBody(useRail),
          ),
          bottomNavigationBar: useRail || keyboardVisible
              ? null
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: NavigationBar(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: (index) {
                          setState(() => _currentIndex = index);
                        },
                        destinations: List.generate(
                          _titles.length,
                          (index) => NavigationDestination(
                            icon: Icon(_icons[index]),
                            label: _titles[index],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildBody(bool useRail) {
    if (useRail) {
      return Row(
        children: [
          SizedBox(
            width: 144,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 0, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: NavigationRail(
                  selectedIndex: _currentIndex,
                  minWidth: 68,
                  minExtendedWidth: 132,
                  labelType: NavigationRailLabelType.selected,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
                  destinations: List.generate(
                    _titles.length,
                    (index) => NavigationRailDestination(
                      icon: Icon(_icons[index]),
                      label: Text(_titles[index]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: IndexedStack(index: _currentIndex, children: _pages),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: IndexedStack(index: _currentIndex, children: _pages),
    );
  }
}
