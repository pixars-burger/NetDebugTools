import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/message_data.dart';
import '../../services/network_tool_service.dart';
import '../../services/send_history_service.dart';
import '../../services/udp_service.dart';
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
    _localPortController.dispose();
    _targetHostController.dispose();
    _targetPortController.dispose();
    _sendController.dispose();
    _sendFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSendHistory() async {
    setState(() {
      _sendHistory = SendHistoryService.instance.udpHistory;
    });
  }

  Future<void> _ping() async {
    final host = _targetHostController.text.trim();
    if (host.isEmpty) {
      setState(() => _pingResult = '请输入目标地址');
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
                main: _buildMainColumn(service),
                side: Column(
                  children: [
                    _buildUdpConfig(service),
                    if (service.errorMessage != null || _pingResult != null)
                      _buildStatusDisplay(service),
                    _buildSendArea(service),
                  ],
                ),
              );
            }

            return Column(
              children: [
                if (!compactForInput) _buildUdpConfig(service),
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

  Widget _buildMainColumn(UdpService service) {
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

  Widget _buildUdpConfig(UdpService service) {
    final summary =
        '${_targetHostController.text.trim()}:${_targetPortController.text.trim()}';

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
                        icon: service.isActive
                            ? Icons.wifi_tethering_rounded
                            : Icons.portable_wifi_off_rounded,
                        label: service.isActive ? 'UDP 已启动' : 'UDP 未启动',
                        color: service.isActive
                            ? const Color(0xFF059669)
                            : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      SectionBadge(
                        icon: Icons.location_searching_rounded,
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
                  onPressed: () => _toggleUdp(service),
                  icon: Icon(
                    service.isActive
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline_rounded,
                  ),
                  label: Text(service.isActive ? '停止' : '启动'),
                  style: FilledButton.styleFrom(
                    backgroundColor: service.isActive
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: service.isActive
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
                  child: TextField(
                    controller: _localPortController,
                    decoration: const InputDecoration(labelText: '本地端口'),
                    keyboardType: TextInputType.number,
                    enabled: !service.isActive,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _targetHostController,
                    decoration: const InputDecoration(labelText: '目标地址'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _targetPortController,
                    decoration: const InputDecoration(labelText: '目标端口'),
                    keyboardType: TextInputType.number,
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

  Widget _buildStatusDisplay(UdpService service) {
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

  Widget _buildSendArea(UdpService service) {
    return AppPanel(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              SectionBadge(
                icon: Icons.send_rounded,
                label: '发送到 ${_targetPortController.text.trim()}',
                color: Theme.of(context).colorScheme.primary,
              ),
              const Spacer(),
              SendHistoryDropdown(
                history: _sendHistory,
                onSelect: (value) => _sendController.text = value,
                onClear: () async {
                  await SendHistoryService.instance.clearUdpHistory();
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
              onPressed: service.isActive ? () => _send(service) : null,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('发送'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUdp(UdpService service) async {
    if (service.isActive) {
      await service.stop();
      if (mounted) {
        setState(() => _configExpanded = true);
      }
      return;
    }

    final localPort =
        int.tryParse(_localPortController.text.trim()) ??
        AppConstants.defaultUdpPort;
    final targetHost = _targetHostController.text.trim();
    final targetPort =
        int.tryParse(_targetPortController.text.trim()) ??
        AppConstants.defaultUdpPort;

    if (localPort < AppConstants.minPort || localPort > AppConstants.maxPort) {
      return;
    }

    await service.start(localPort, targetHost, targetPort);
    if (mounted && service.isActive) {
      setState(() => _configExpanded = false);
    }
  }

  Future<void> _send(UdpService service) async {
    final text = _sendController.text;
    if (text.isEmpty) {
      return;
    }

    final targetHost = _targetHostController.text.trim();
    final targetPort =
        int.tryParse(_targetPortController.text.trim()) ?? service.targetPort;
    service.setTarget(targetHost, targetPort);

    final result = DataConverter.stringToBytes(text, _sendFormat, _encoding);
    if (!result.isSuccess) {
      setState(() => _pingResult = result.error);
      return;
    }

    final success = await service.send(result.data!);
    if (!success) {
      return;
    }

    await SendHistoryService.instance.addUdpHistory(text);
    _loadSendHistory();
  }
}
