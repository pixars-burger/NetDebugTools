import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/message_data.dart';
import '../../services/network_tool_service.dart';
import '../../services/send_history_service.dart';
import '../../services/tcp_client_service.dart';
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
  final _sendFocusNode = FocusNode();

  DataFormat _sendFormat = DataFormat.text;
  DataFormat _receiveFormat = DataFormat.text;
  CharEncoding _encoding = CharEncoding.utf8;
  bool _isPinging = false;
  bool _configExpanded = true;
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
    _sendFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSendHistory() async {
    setState(() {
      _sendHistory = SendHistoryService.instance.tcpClientHistory;
    });
  }

  Future<void> _ping() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      setState(() => _pingResult = '请输入主机地址');
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final landscape =
                constraints.maxWidth > constraints.maxHeight &&
                constraints.maxWidth >= 700;
            final keyboardVisible = View.of(context).viewInsets.bottom > 0;
            final compactForInput = keyboardVisible && _sendFocusNode.hasFocus;

            if (landscape) {
              return SplitView(
                mainFlex: 6,
                sideFlex: 4,
                main: _buildMainColumn(service, landscape: true),
                side: Column(
                  children: [
                    _buildConnectionConfig(service),
                    if (service.errorMessage != null || _pingResult != null)
                      _buildStatusDisplay(service),
                    _buildSendArea(service),
                  ],
                ),
              );
            }

            return Column(
              children: [
                if (!compactForInput) _buildConnectionConfig(service),
                if (!compactForInput &&
                    (service.errorMessage != null || _pingResult != null))
                  _buildStatusDisplay(service),
                Expanded(
                  child: Column(
                    children: [
                      if (!compactForInput)
                        CompactStatisticsPanel(
                          statistics: service.statistics,
                          onReset: service.resetStatistics,
                        ),
                      if (!compactForInput) _buildFormatSelector(),
                      Expanded(
                        child: DataDisplayList(
                          messages: service.messages,
                          displayFormat: _receiveFormat,
                          encoding: _encoding,
                          isPaused: service.isPaused,
                          onClear: service.clearMessages,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildSendArea(service),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMainColumn(TcpClientService service, {bool landscape = false}) {
    return Column(
      children: [
        CompactStatisticsPanel(
          statistics: service.statistics,
          onReset: service.resetStatistics,
        ),
        _buildFormatSelector(),
        Expanded(
          child: DataDisplayList(
            messages: service.messages,
            displayFormat: _receiveFormat,
            encoding: _encoding,
            isPaused: service.isPaused,
            onClear: service.clearMessages,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionConfig(TcpClientService service) {
    final summary =
        '${_hostController.text.trim()}:${_portController.text.trim()}';

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
                        icon: service.isConnected
                            ? Icons.link_rounded
                            : Icons.link_off_rounded,
                        label: service.isConnected ? '已连接' : '未连接',
                        color: service.isConnected
                            ? const Color(0xFF059669)
                            : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      SectionBadge(
                        icon: Icons.dns_rounded,
                        label: summary,
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
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isPinging ? null : _ping,
                  icon: _isPinging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_ping_rounded, size: 18),
                  label: const Text('Ping'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _toggleConnection(service),
                  icon: Icon(
                    service.isConnected
                        ? Icons.link_off_rounded
                        : Icons.link_rounded,
                    size: 18,
                  ),
                  label: Text(service.isConnected ? '断开' : '连接'),
                  style: FilledButton.styleFrom(
                    backgroundColor: service.isConnected
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: service.isConnected
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
          if (_configExpanded) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(labelText: '主机地址'),
                    enabled: !service.isConnected,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(labelText: '端口'),
                    keyboardType: TextInputType.number,
                    enabled: !service.isConnected,
                  ),
                ),
              ],
            ),
          ],
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

  Widget _buildStatusDisplay(TcpClientService service) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          if (service.errorMessage != null)
            ErrorDisplay(
              errorMessage: service.errorMessage,
              onDismiss: service.clearError,
            ),
          if (_pingResult != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(_pingResult!, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildSendArea(TcpClientService service) {
    return AppPanel(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              SectionBadge(
                icon: Icons.send_rounded,
                label: _sendFormat == DataFormat.hex ? 'HEX 发送' : '快速发送',
                color: Theme.of(context).colorScheme.primary,
              ),
              const Spacer(),
              SendHistoryDropdown(
                history: _sendHistory,
                onSelect: (value) => _sendController.text = value,
                onClear: () async {
                  await SendHistoryService.instance.clearTcpClientHistory();
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
              onPressed: service.isConnected ? () => _send(service) : null,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('发送'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleConnection(TcpClientService service) async {
    if (service.isConnected) {
      await service.disconnect();
      if (mounted) {
        setState(() => _configExpanded = true);
      }
      return;
    }

    final host = _hostController.text.trim();
    final port =
        int.tryParse(_portController.text.trim()) ??
        AppConstants.defaultTcpPort;
    if (host.isEmpty) {
      return;
    }
    if (port < AppConstants.minPort || port > AppConstants.maxPort) {
      return;
    }

    await service.connect(host, port);
    if (mounted && service.isConnected) {
      setState(() => _configExpanded = false);
    }
  }

  Future<void> _send(TcpClientService service) async {
    final text = _sendController.text;
    if (text.isEmpty) {
      return;
    }

    final result = DataConverter.stringToBytes(text, _sendFormat, _encoding);
    if (!result.isSuccess) {
      setState(() => _pingResult = result.error);
      return;
    }

    final success = await service.send(result.data!);
    if (!success) {
      return;
    }

    await SendHistoryService.instance.addTcpClientHistory(text);
    _loadSendHistory();
  }
}
