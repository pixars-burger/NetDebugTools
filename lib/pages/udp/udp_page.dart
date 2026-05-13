import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme_controller.dart';
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
        return ProtocolScreenScaffold(
          topSummary: _buildTopActions(service),
          mainContent: Column(
            children: [
              Expanded(
                child: DataDisplayList(
                  messages: service.messages,
                  displayFormat: _receiveFormat,
                  encoding: _encoding,
                  isPaused: service.isPaused,
                  onClear: service.clearMessages,
                  showToolbar: false,
                ),
              ),
            ],
          ),
          sideContent: Column(
            children: [
              _buildUdpSummary(service),
              _buildFormatSelector(),
              if (service.errorMessage != null || _pingResult != null)
                _buildStatusDisplay(service),
              _buildSendArea(service),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopActions(UdpService service) {
    return Row(
      children: [
        IconButton.outlined(
          onPressed: () => _showConfigSheet(service),
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'UDP 配置',
        ),
        const SizedBox(width: 8),
        Builder(
          builder: (context) {
            final themeController = Provider.of<AppThemeController?>(context);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return IconButton.outlined(
              onPressed: themeController == null
                  ? null
                  : () => themeController.toggleFromBrightness(
                        Theme.of(context).brightness,
                      ),
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              tooltip: '切换明暗主题',
            );
          },
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          onPressed: service.isActive
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

  Widget _buildUdpSummary(UdpService service) {
    final summary =
        '${_targetHostController.text.trim()}:${_targetPortController.text.trim()}';
    return ConnectionSummaryBar(
      isConnected: service.isActive,
      statusLabel: service.isActive ? 'UDP 已启动' : 'UDP 未启动',
      endpointLabel: summary,
      speedLabel: '↑${service.statistics.formattedSentBytes} ↓${service.statistics.formattedReceivedBytes}',
      modeLabel: _sendFormat == DataFormat.hex ? 'HEX 发送' : '快速发送',
      onToggleConnection: () => _toggleUdp(service),
      showConnectButton: false,
      isPaused: service.isPaused,
      onTogglePause: null,
    );
  }

  Widget _buildUdpConfig(UdpService service) {
    final lowPortWarning = _buildLowPortWarning(
      _localPortController.text.trim(),
    );

    return AppPanel(
      child: Column(
        children: [
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
          const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _localPortController,
                    decoration: const InputDecoration(labelText: '本地端口'),
                    keyboardType: TextInputType.number,
                    enabled: !service.isActive,
                    onChanged: (_) => setState(() {}),
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
            if (lowPortWarning != null) ...[
              const SizedBox(height: 8),
              lowPortWarning,
            ],
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
                  await SendHistoryService.instance.clearUdpHistory();
                  _loadSendHistory();
                },
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: service.isActive ? () => _send(service) : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('发送'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showConfigSheet(UdpService service) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Consumer<UdpService>(builder: (context, liveService, _) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(child: _buildUdpConfig(liveService)),
      )),
    );
  }

  Future<void> _toggleUdp(UdpService service) async {
    if (service.isActive) {
      await service.stop();
      return;
    }

    final localPort =
        int.tryParse(_localPortController.text.trim()) ??
        AppConstants.defaultUdpPort;
    final targetHost = _targetHostController.text.trim();
    final targetPort =
        int.tryParse(_targetPortController.text.trim()) ??
        AppConstants.defaultUdpPort;

    if (localPort < AppConstants.minBindablePort ||
        localPort > AppConstants.maxPort) {
      return;
    }

    await service.start(localPort, targetHost, targetPort);
    if (mounted) setState(() {});
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
