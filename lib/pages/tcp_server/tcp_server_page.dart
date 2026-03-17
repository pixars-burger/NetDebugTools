import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/message_data.dart';
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
  bool _configExpanded = true;

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
      if (ips.isNotEmpty) {
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final landscape =
                constraints.maxWidth > constraints.maxHeight &&
                constraints.maxWidth >= 700;
            final keyboardVisible = View.of(context).viewInsets.bottom > 0;
            final compactForInput = keyboardVisible && _sendFocusNode.hasFocus;

            final errorWidget = service.errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ErrorDisplay(
                      errorMessage: service.errorMessage,
                      onDismiss: service.clearError,
                    ),
                  )
                : null;

            if (landscape) {
              return SplitView(
                mainFlex: 7,
                sideFlex: 4,
                main: Column(
                  children: [
                    CompactStatisticsPanel(
                      statistics: service.statistics,
                      onReset: service.resetStatistics,
                    ),
                    _buildTabStrip(service),
                    Expanded(child: _buildTabContent(service)),
                  ],
                ),
                side: Column(
                  children: [
                    _buildServerConfig(service),
                    if (errorWidget != null) errorWidget,
                    _buildFormatSelector(),
                    _buildSendArea(service),
                  ],
                ),
              );
            }

            return Column(
              children: [
                if (!compactForInput) _buildServerConfig(service),
                if (!compactForInput && errorWidget != null) errorWidget,
                if (!compactForInput)
                  CompactStatisticsPanel(
                    statistics: service.statistics,
                    onReset: service.resetStatistics,
                  ),
                if (!compactForInput) _buildFormatSelector(),
                if (!compactForInput) _buildTabStrip(service),
                Expanded(child: _buildTabContent(service)),
                const SizedBox(height: 8),
                _buildSendArea(service),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildServerConfig(TcpServerService service) {
    return AppPanel(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SectionBadge(
                        icon: service.isRunning
                            ? Icons.settings_input_component_rounded
                            : Icons.power_settings_new_rounded,
                        label: service.isRunning ? '服务运行中' : '服务未启动',
                        color: service.isRunning
                            ? const Color(0xFF059669)
                            : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      SectionBadge(
                        icon: Icons.dns_rounded,
                        label: '$_selectedIP:${_portController.text.trim()}',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      SectionBadge(
                        icon: Icons.devices_rounded,
                        label: '${service.clientCount} 个客户端',
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _configExpanded = !_configExpanded);
                },
                icon: Icon(
                  _configExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ),
            ],
          ),
          if (_configExpanded) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedIP,
                    decoration: const InputDecoration(labelText: '本机 IP'),
                    items: _localIPs.map((ip) {
                      return DropdownMenuItem<String>(
                        value: ip.address,
                        child: Text(
                          '${ip.address} (${ip.name})',
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
                  ),
                ),
              ],
            ),
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
    final target = _selectedClientId != null
        ? service.clients[_selectedClientId]?.displayAddress ?? '未知客户端'
        : '广播模式';

    return AppPanel(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SectionBadge(
                  icon: _selectedClientId != null
                      ? Icons.filter_1_rounded
                      : Icons.campaign_rounded,
                  label: target,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              SendHistoryDropdown(
                history: _sendHistory,
                onSelect: (value) => _sendController.text = value,
                onClear: () async {
                  await SendHistoryService.instance.clearTcpServerHistory();
                  _loadSendHistory();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sendController,
            focusNode: _sendFocusNode,
            decoration: const InputDecoration(hintText: '输入要发送的数据...'),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: service.isRunning && service.clientCount > 0
                  ? () => _send(service)
                  : null,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(_selectedClientId != null ? '发送到客户端' : '广播'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleServer(TcpServerService service) async {
    if (service.isRunning) {
      await service.stop();
      if (mounted) {
        setState(() => _configExpanded = true);
      }
      return;
    }

    final port =
        int.tryParse(_portController.text.trim()) ??
        AppConstants.defaultTcpPort;
    if (port < AppConstants.minPort || port > AppConstants.maxPort) {
      return;
    }

    await service.start(_selectedIP, port);
    if (mounted && service.isRunning) {
      setState(() => _configExpanded = false);
    }
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
