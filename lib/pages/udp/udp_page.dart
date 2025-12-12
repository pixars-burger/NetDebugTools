import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/message_data.dart';
import '../../services/udp_service.dart';
import '../../services/network_tool_service.dart';
import '../../services/send_history_service.dart';
import '../../utils/constants.dart';
import '../../utils/data_converter.dart';
import '../../widgets/widgets.dart';

class UdpPage extends StatefulWidget {
  const UdpPage({super.key});

  @override
  State<UdpPage> createState() => _UdpPageState();
}

class _UdpPageState extends State<UdpPage> {
  final _localPortController = TextEditingController(text: '8081');
  final _targetHostController = TextEditingController(text: '192.168.1.1');
  final _targetPortController = TextEditingController(text: '8081');
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
    _localPortController.dispose();
    _targetHostController.dispose();
    _targetPortController.dispose();
    _sendController.dispose();
    super.dispose();
  }

  Future<void> _loadSendHistory() async {
    final history = SendHistoryService.instance.udpHistory;
    setState(() {
      _sendHistory = history;
    });
  }

  Future<void> _ping() async {
    final host = _targetHostController.text.trim();
    if (host.isEmpty) {
      setState(() {
        _pingResult = '请输入目标地址';
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
    return Consumer<UdpService>(
      builder: (context, service, child) {
        return Column(
          children: [
            // UDP配置区域
            _buildUdpConfig(service),
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

  Widget _buildUdpConfig(UdpService service) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // 本地端口
            Row(
              children: [
                const Text('本地端口: '),
                Expanded(
                  child: TextField(
                    controller: _localPortController,
                    decoration: const InputDecoration(
                      hintText: '本地监听端口',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !service.isActive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 目标地址
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _targetHostController,
                    decoration: const InputDecoration(
                      labelText: '目标地址',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _targetPortController,
                    decoration: const InputDecoration(
                      labelText: '目标端口',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
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
                // 启动/停止按钮
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _toggleUdp(service),
                    icon: Icon(
                      service.isActive ? Icons.stop : Icons.play_arrow,
                      size: 18,
                    ),
                    label: Text(service.isActive ? '停止' : '启动'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: service.isActive
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 暂停/继续按钮
                IconButton(
                  onPressed: service.isActive
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

  Widget _buildStatusDisplay(UdpService service) {
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

  Widget _buildSendArea(UdpService service) {
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
                await SendHistoryService.instance.clearUdpHistory();
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
              onPressed: service.isActive ? () => _send(service) : null,
              child: const Text('发送'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleUdp(UdpService service) async {
    if (service.isActive) {
      await service.stop();
    } else {
      final localPort =
          int.tryParse(_localPortController.text.trim()) ??
          AppConstants.defaultUdpPort;
      final targetHost = _targetHostController.text.trim();
      final targetPort =
          int.tryParse(_targetPortController.text.trim()) ??
          AppConstants.defaultUdpPort;

      if (localPort < AppConstants.minPort ||
          localPort > AppConstants.maxPort) {
        return;
      }

      await service.start(localPort, targetHost, targetPort);
    }
  }

  Future<void> _send(UdpService service) async {
    final text = _sendController.text;
    if (text.isEmpty) return;

    // 更新目标地址
    final targetHost = _targetHostController.text.trim();
    final targetPort =
        int.tryParse(_targetPortController.text.trim()) ?? service.targetPort;
    service.setTarget(targetHost, targetPort);

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
      await SendHistoryService.instance.addUdpHistory(text);
      _loadSendHistory();
    }
  }
}
