import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message_data.dart';
import '../../services/tcp_server_service.dart';
import '../../services/network_tool_service.dart';
import '../../services/send_history_service.dart';
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
    final history = SendHistoryService.instance.tcpServerHistory;
    setState(() {
      _sendHistory = history;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TcpServerService>(
      builder: (context, service, child) {
        return Column(
          children: [
            // 服务器配置区域
            _buildServerConfig(service),
            // 格式选择
            _buildFormatSelector(),
            // 错误提示
            if (service.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ErrorDisplay(
                  errorMessage: service.errorMessage,
                  onDismiss: () => service.clearError(),
                ),
              ),
            // 统计信息
            CompactStatisticsPanel(
              statistics: service.statistics,
              onReset: () => service.resetStatistics(),
            ),
            // Tab栏
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: '消息 (${service.messages.length})'),
                Tab(text: '客户端 (${service.clientCount})'),
                Tab(text: '历史 (${service.connectionHistory.length})'),
              ],
            ),
            // Tab内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 消息列表
                  DataDisplayList(
                    messages: service.messages,
                    displayFormat: _receiveFormat,
                    encoding: _encoding,
                    isPaused: service.isPaused,
                    onClear: () => service.clearMessages(),
                  ),
                  // 客户端列表
                  _buildClientList(service),
                  // 连接历史
                  _buildConnectionHistory(service),
                ],
              ),
            ),
            // 发送区域
            _buildSendArea(service),
          ],
        );
      },
    );
  }

  Widget _buildServerConfig(TcpServerService service) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // IP选择
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedIP,
                    decoration: const InputDecoration(
                      labelText: '本机IP',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: _localIPs.map((ip) {
                      return DropdownMenuItem(
                        value: ip.address,
                        child: Text(
                          '${ip.address} (${ip.name})',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
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
                // 端口输入
                Expanded(
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !service.isRunning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // 刷新IP按钮
                IconButton(
                  onPressed: _loadLocalIPs,
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新IP列表',
                ),
                const SizedBox(width: 8),
                // 启动/停止按钮
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleServer(service),
                    icon: Icon(
                      service.isRunning ? Icons.stop : Icons.play_arrow,
                      size: 18,
                    ),
                    label: Text(service.isRunning ? '停止服务器' : '启动服务器'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: service.isRunning
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 暂停/继续按钮
                IconButton(
                  onPressed: service.isRunning
                      ? () {
                          if (service.isPaused) {
                            service.resume();
                          } else {
                            service.pause();
                          }
                        }
                      : null,
                  icon: Icon(service.isPaused ? Icons.play_arrow : Icons.pause),
                  tooltip: service.isPaused ? '继续接收' : '暂停接收',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: DualFormatSelector(
              sendFormat: _sendFormat,
              receiveFormat: _receiveFormat,
              onSendFormatChanged: (format) =>
                  setState(() => _sendFormat = format),
              onReceiveFormatChanged: (format) =>
                  setState(() => _receiveFormat = format),
            ),
          ),
          const SizedBox(width: 8),
          EncodingSelector(
            label: '编码',
            value: _encoding,
            onChanged: (encoding) => setState(() => _encoding = encoding),
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildClientList(TcpServerService service) {
    final clients = service.clientList;

    if (clients.isEmpty) {
      return const Center(child: Text('暂无客户端连接'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        final isSelected = _selectedClientId == client.id;

        return Card(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.green,
              child: const Icon(Icons.devices, color: Colors.white, size: 20),
            ),
            title: Text(client.displayAddress),
            subtitle: Text(
              '连接时间: ${TimestampFormatter.formatShort(client.connectedAt)}\n'
              '收发: ${client.statistics.formattedReceivedBytes}/${client.statistics.formattedSentBytes}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 选择按钮
                IconButton(
                  icon: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedClientId = isSelected ? null : client.id;
                    });
                  },
                  tooltip: '选择此客户端发送',
                ),
                // 断开按钮
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => service.disconnectClient(client.id),
                  tooltip: '断开连接',
                ),
              ],
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
        // 清空按钮
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => service.clearConnectionHistory(),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清空历史'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final info = history[index];

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.history, color: Colors.white, size: 20),
                  ),
                  title: Text(info.displayAddress),
                  subtitle: Text(
                    '连接: ${TimestampFormatter.formatShort(info.connectedAt)}\n'
                    '断开: ${info.disconnectedAt != null ? TimestampFormatter.formatShort(info.disconnectedAt!) : '-'}\n'
                    '时长: ${info.formattedDuration}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => service.removeConnectionHistory(info.id),
                    tooltip: '删除记录',
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
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // 发送模式提示
            if (_selectedClientId != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '单播模式: 发送到 ${service.clients[_selectedClientId]?.displayAddress ?? "未知"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 发送历史
                SendHistoryDropdown(
                  history: _sendHistory,
                  onSelect: (value) {
                    _sendController.text = value;
                  },
                  onClear: () async {
                    await SendHistoryService.instance.clearTcpServerHistory();
                    _loadSendHistory();
                  },
                ),
                const SizedBox(width: 8),
                // 发送输入框
                Expanded(
                  child: TextField(
                    controller: _sendController,
                    decoration: const InputDecoration(
                      hintText: '输入要发送的数据...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                // 发送按钮
                ElevatedButton(
                  onPressed: service.isRunning && service.clientCount > 0
                      ? () => _send(service)
                      : null,
                  child: Text(_selectedClientId != null ? '发送' : '广播'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleServer(TcpServerService service) async {
    if (service.isRunning) {
      await service.stop();
    } else {
      final port =
          int.tryParse(_portController.text.trim()) ??
          AppConstants.defaultTcpPort;

      if (port < AppConstants.minPort || port > AppConstants.maxPort) {
        return;
      }

      await service.start(_selectedIP, port);
    }
  }

  Future<void> _send(TcpServerService service) async {
    final text = _sendController.text;
    if (text.isEmpty) return;

    final result = DataConverter.stringToBytes(text, _sendFormat, _encoding);
    if (!result.isSuccess) {
      return;
    }

    bool success;
    if (_selectedClientId != null) {
      // 单播
      success = await service.sendToClient(_selectedClientId!, result.data!);
    } else {
      // 广播
      final count = await service.broadcast(result.data!);
      success = count > 0;
    }

    if (success) {
      // 保存到历史
      await SendHistoryService.instance.addTcpServerHistory(text);
      _loadSendHistory();
    }
  }
}
