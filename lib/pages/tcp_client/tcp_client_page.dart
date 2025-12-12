import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message_data.dart';
import '../../services/tcp_client_service.dart';
import '../../services/network_tool_service.dart';
import '../../services/send_history_service.dart';
import '../../utils/constants.dart';
import '../../utils/data_converter.dart';
import '../../widgets/widgets.dart';

class TcpClientPage extends StatefulWidget {
  const TcpClientPage({super.key});

  @override
  State<TcpClientPage> createState() => _TcpClientPageState();
}

class _TcpClientPageState extends State<TcpClientPage> {
  final _hostController = TextEditingController(text: '192.168.1.1');
  final _portController = TextEditingController(text: '8080');
  final _sendController = TextEditingController();

  DataFormat _sendFormat = DataFormat.text;
  DataFormat _receiveFormat = DataFormat.text;
  CharEncoding _encoding = CharEncoding.utf8;
  bool _isPinging = false;
  String? _pingResult;
  List<String> _sendHistory = [];

  @override
  void initState() {
    super.initState();
    _loadSendHistory();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _sendController.dispose();
    super.dispose();
  }

  Future<void> _loadSendHistory() async {
    final history = SendHistoryService.instance.tcpClientHistory;
    setState(() {
      _sendHistory = history;
    });
  }

  Future<void> _ping() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      setState(() {
        _pingResult = '请输入主机地址';
      });
      return;
    }

    setState(() {
      _isPinging = true;
      _pingResult = null;
    });

    final result = await NetworkToolService.ping(host);

    setState(() {
      _isPinging = false;
      _pingResult = result.summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TcpClientService>(
      builder: (context, service, child) {
        return Column(
          children: [
            // 连接配置区域
            _buildConnectionConfig(service),
            // 格式选择
            _buildFormatSelector(),
            // 错误/状态提示
            if (service.errorMessage != null || _pingResult != null)
              _buildStatusDisplay(service),
            // 统计信息
            CompactStatisticsPanel(
              statistics: service.statistics,
              onReset: () => service.resetStatistics(),
            ),
            // 数据展示区域
            Expanded(
              child: DataDisplayList(
                messages: service.messages,
                displayFormat: _receiveFormat,
                encoding: _encoding,
                isPaused: service.isPaused,
                onClear: () => service.clearMessages(),
              ),
            ),
            // 发送区域
            _buildSendArea(service),
          ],
        );
      },
    );
  }

  Widget _buildConnectionConfig(TcpClientService service) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: '主机地址',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    enabled: !service.isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !service.isConnected,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Ping按钮
                OutlinedButton.icon(
                  onPressed: _isPinging ? null : _ping,
                  icon: _isPinging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_ping, size: 18),
                  label: const Text('Ping'),
                ),
                const SizedBox(width: 8),
                // 连接/断开按钮
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleConnection(service),
                    icon: Icon(
                      service.isConnected ? Icons.link_off : Icons.link,
                      size: 18,
                    ),
                    label: Text(service.isConnected ? '断开' : '连接'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: service.isConnected
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 暂停/继续按钮
                IconButton(
                  onPressed: service.isConnected
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

  Widget _buildStatusDisplay(TcpClientService service) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          if (service.errorMessage != null)
            ErrorDisplay(
              errorMessage: service.errorMessage,
              onDismiss: () => service.clearError(),
            ),
          if (_pingResult != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_pingResult!, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildSendArea(TcpClientService service) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 发送历史
            SendHistoryDropdown(
              history: _sendHistory,
              onSelect: (value) {
                _sendController.text = value;
              },
              onClear: () async {
                await SendHistoryService.instance.clearTcpClientHistory();
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
              onPressed: service.isConnected ? () => _send(service) : null,
              child: const Text('发送'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleConnection(TcpClientService service) async {
    if (service.isConnected) {
      await service.disconnect();
    } else {
      final host = _hostController.text.trim();
      final port =
          int.tryParse(_portController.text.trim()) ??
          AppConstants.defaultTcpPort;

      if (host.isEmpty) {
        service.clearError();
        return;
      }

      if (port < AppConstants.minPort || port > AppConstants.maxPort) {
        return;
      }

      await service.connect(host, port);
    }
  }

  Future<void> _send(TcpClientService service) async {
    final text = _sendController.text;
    if (text.isEmpty) return;

    final result = DataConverter.stringToBytes(text, _sendFormat, _encoding);
    if (!result.isSuccess) {
      setState(() {
        _pingResult = result.error;
      });
      return;
    }

    final success = await service.send(result.data!);
    if (success) {
      // 保存到历史
      await SendHistoryService.instance.addTcpClientHistory(text);
      _loadSendHistory();
    }
  }
}
