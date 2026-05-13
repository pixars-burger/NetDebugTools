import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/message_data.dart';
import '../../core/theme/app_theme_controller.dart';
import '../../services/network_tool_service.dart';
import '../../services/send_history_service.dart';
import '../../services/tcp_server_service.dart';
import '../../utils/constants.dart';
import '../../utils/data_converter.dart';
import '../../utils/timestamp_formatter.dart';
import '../../widgets/widgets.dart';

class TcpServerPage extends StatefulWidget {
  const TcpServerPage({super.key});

  @override
  State<TcpServerPage> createState() => _TcpServerPageState();
}

class _TcpServerPageState extends State<TcpServerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _portController = TextEditingController(text: '8080');
  final _sendController = TextEditingController();
  final _sendFocusNode = FocusNode();

  List<NetworkInterfaceInfo> _localIPs = [];
  String _selectedIP = '0.0.0.0';
  DataFormat _sendFormat = DataFormat.text;
  DataFormat _receiveFormat = DataFormat.text;
  CharEncoding _encoding = CharEncoding.utf8;
  String? _selectedClientId;
  List<String> _sendHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLocalIPs();
    _loadSendHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _portController.dispose();
    _sendController.dispose();
    _sendFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadLocalIPs() async {
    final ips = await NetworkToolService.getLocalIPs();
    setState(() {
      _localIPs = ips;
      final selectedExists = ips.any((ip) => ip.address == _selectedIP);
      if (!selectedExists && ips.isNotEmpty) {
        _selectedIP = ips.first.address;
      }
    });
  }

  Future<void> _loadSendHistory() async {
    setState(() {
      _sendHistory = SendHistoryService.instance.tcpServerHistory;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TcpServerService>(
      builder: (context, service, child) {
        final errorWidget = service.errorMessage != null
            ? Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ErrorDisplay(
                  errorMessage: service.errorMessage,
                  onDismiss: service.clearError,
                ),
              )
            : null;

        return ProtocolScreenScaffold(
          topSummary: Column(
            children: [
              _buildTopActions(service),
              if (errorWidget != null) errorWidget,
            ],
          ),
          mainContent: Column(
            children: [
              _buildTabStrip(service),
              Expanded(child: _buildTabContent(service)),
            ],
          ),
          sideContent: Column(
            children: [
              _buildServerSummary(service),
              _buildFormatSelector(),
              _buildSendArea(service),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopActions(TcpServerService service) {
    return Row(
      children: [
        IconButton.outlined(
          onPressed: () => _showConfigSheet(service),
          icon: const Icon(Icons.tune_rounded),
          tooltip: '服务配置',
        ),
        const SizedBox(width: 8),
        Builder(
          builder: (context) {
            final themeController = Provider.of<AppThemeController?>(context);
            final isDark = themeController?.themeMode == ThemeMode.dark;
            return IconButton.outlined(
              onPressed: themeController?.toggleLightDark,
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              tooltip: '切换明暗主题',
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          onPressed: service.isRunning
              ? () => service.isPaused ? service.resume() : service.pause()
              : null,
          icon: Icon(service.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
          tooltip: '暂停/恢复',
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          onPressed: service.clearMessages,
          icon: const Icon(Icons.delete_sweep_rounded),
          tooltip: '清空消息',
        ),
      ],
    );
  }

  Widget _buildServerSummary(TcpServerService service) {
    return ConnectionSummaryBar(
      isConnected: service.isRunning,
      statusLabel: service.isRunning ? '服务运行中' : '服务未启动',
      endpointLabel: '$_selectedIP:${_portController.text.trim()}',
      speedLabel: '↑${service.statistics.formattedSentBytes} ↓${service.statistics.formattedReceivedBytes}',
      modeLabel: _selectedClientId != null ? '单播模式' : '广播模式',
      onToggleConnection: () => _toggleServer(service),
      showConnectButton: false,
      isPaused: service.isPaused,
      onTogglePause: null,
    );
  }

  Widget _buildServerConfig(TcpServerService service) {
    final lowPortWarning = _buildLowPortWarning(_portController.text.trim());

    return AppPanel(
      child: Column(
        children: [
          const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedIP,
                    decoration: const InputDecoration(labelText: '本机 IP'),
                    items: _localIPs.map((ip) {
                      final isAnyIpv4 =
                          ip.address == NetworkToolService.anyIpv4Address;
                      return DropdownMenuItem<String>(
                        value: ip.address,
                        child: Text(
                          isAnyIpv4
                              ? '${ip.address} (${ip.name})'
                              : '${ip.address} (${ip.name})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: service.isRunning
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedIP = value);
                            }
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(labelText: '端口'),
                    keyboardType: TextInputType.number,
                    enabled: !service.isRunning,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (lowPortWarning != null) ...[
              const SizedBox(height: 8),
              lowPortWarning,
            ],
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _loadLocalIPs,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('刷新 IP'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _toggleServer(service),
                  icon: Icon(
                    service.isRunning
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline_rounded,
                  ),
                  label: Text(service.isRunning ? '停止服务' : '启动服务'),
                  style: FilledButton.styleFrom(
                    backgroundColor: service.isRunning
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: service.isRunning
                      ? () {
                          service.isPaused ? service.resume() : service.pause();
                        }
                      : null,
                  icon: Icon(
                    service.isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildLowPortWarning(String value) {
    if (!Platform.isAndroid) {
      return null;
    }

    final port = int.tryParse(value);
    if (port == null || port >= 1024 || port < AppConstants.minBindablePort) {
      return null;
    }

    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '低于 1024 的端口在 Android 上通常需要更高权限，普通设备可能无法监听成功。',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            DualFormatSelector(
              sendFormat: _sendFormat,
              receiveFormat: _receiveFormat,
              onSendFormatChanged: (format) =>
                  setState(() => _sendFormat = format),
              onReceiveFormatChanged: (format) =>
                  setState(() => _receiveFormat = format),
            ),
            const SizedBox(width: 6),
            EncodingSelector(
              label: '编码',
              value: _encoding,
              onChanged: (encoding) => setState(() => _encoding = encoding),
              dense: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabStrip(TcpServerService service) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(height: 34, child: Text('消息 ${service.messages.length}')),
          Tab(height: 34, child: Text('客户端 ${service.clientCount}')),
          Tab(
            height: 34,
            child: Text('历史 ${service.connectionHistory.length}'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(TcpServerService service) {
    return TabBarView(
      controller: _tabController,
      children: [
        DataDisplayList(
          messages: service.messages,
          displayFormat: _receiveFormat,
          encoding: _encoding,
          isPaused: service.isPaused,
          onClear: service.clearMessages,
          showToolbar: false,
        ),
        _buildClientList(service),
        _buildConnectionHistory(service),
      ],
    );
  }

  Widget _buildClientList(TcpServerService service) {
    final clients = service.clientList;
    if (clients.isEmpty) {
      return const Center(child: Text('暂无客户端连接'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        final isSelected = _selectedClientId == client.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFF059669),
                child: const Icon(Icons.devices_rounded, color: Colors.white),
              ),
              title: Text(client.displayAddress),
              subtitle: Text(
                '连接时间 ${TimestampFormatter.formatShort(client.connectedAt)}\n'
                '收发 ${client.statistics.formattedReceivedBytes} / ${client.statistics.formattedSentBytes}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    icon: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedClientId = isSelected ? null : client.id;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.red),
                    onPressed: () => service.disconnectClient(client.id),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionHistory(TcpServerService service) {
    final history = service.connectionHistory;
    if (history.isEmpty) {
      return const Center(child: Text('暂无连接历史'));
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: service.clearConnectionHistory,
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('清空历史'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final info = history[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.history_rounded),
                    ),
                    title: Text(info.displayAddress),
                    subtitle: Text(
                      '连接 ${TimestampFormatter.formatShort(info.connectedAt)}\n'
                      '断开 ${info.disconnectedAt != null ? TimestampFormatter.formatShort(info.disconnectedAt!) : '-'}\n'
                      '时长 ${info.formattedDuration}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => service.removeConnectionHistory(info.id),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSendArea(TcpServerService service) {
    return AppPanel(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          TextField(
            controller: _sendController,
            focusNode: _sendFocusNode,
            decoration: const InputDecoration(hintText: '输入要发送的数据...'),
            maxLines: 2,
            minLines: 1,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              SendHistoryDropdown(
                history: _sendHistory,
                onSelect: (value) => _sendController.text = value,
                onClear: () async {
                  await SendHistoryService.instance.clearTcpServerHistory();
                  _loadSendHistory();
                },
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: service.isRunning && service.clientCount > 0
                    ? () => _send(service)
                    : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(_selectedClientId != null ? '发送' : '广播'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showConfigSheet(TcpServerService service) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Consumer<TcpServerService>(builder: (context, liveService, _) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(child: _buildServerConfig(liveService)),
      )),
    );
  }

  Future<void> _toggleServer(TcpServerService service) async {
    if (service.isRunning) {
      await service.stop();
      return;
    }

    final port =
        int.tryParse(_portController.text.trim()) ??
        AppConstants.defaultTcpPort;
    if (port < AppConstants.minBindablePort || port > AppConstants.maxPort) {
      return;
    }

    await service.start(_selectedIP, port);
    if (mounted) setState(() {});
  }

  Future<void> _send(TcpServerService service) async {
    final text = _sendController.text;
    if (text.isEmpty) {
      return;
    }

    final result = DataConverter.stringToBytes(text, _sendFormat, _encoding);
    if (!result.isSuccess) {
      return;
    }

    final success = _selectedClientId != null
        ? await service.sendToClient(_selectedClientId!, result.data!)
        : await service.broadcast(result.data!) > 0;

    if (!success) {
      return;
    }

    await SendHistoryService.instance.addTcpServerHistory(text);
    _loadSendHistory();
  }
}
