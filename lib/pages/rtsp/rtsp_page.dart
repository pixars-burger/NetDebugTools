import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme_controller.dart';
import '../../widgets/widgets.dart';

class RtspPage extends StatefulWidget {
  const RtspPage({super.key});

  @override
  State<RtspPage> createState() => _RtspPageState();
}

class _RtspPageState extends State<RtspPage> {
  static const String _rtspUrlKey = 'rtsp.last_url';
  final TextEditingController _urlController = TextEditingController(
    text: 'rtsp://192.168.1.10:554/stream',
  );

  late final Player _player;
  late final VideoController _videoController;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<String>? _errorSub;

  bool _isPlaying = false;
  bool _isBuffering = false;
  DateTime? _startAt;
  Duration? _firstFrameDuration;
  int _reconnectCount = 0;
  String _lastError = '--';
  String _resolution = '--';
  bool _rotateClockwise = false;

  @override
  void initState() {
    super.initState();
    _restoreLastUrl();
    MediaKit.ensureInitialized();
    _player = Player();
    _videoController = VideoController(_player);
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      if (playing && _startAt != null && _firstFrameDuration == null) {
        _firstFrameDuration = DateTime.now().difference(_startAt!);
      }
      setState(() => _isPlaying = playing);
    });
    _errorSub = _player.stream.error.listen((error) {
      if (!mounted) return;
      setState(() {
        _lastError = error;
        _reconnectCount += 1;
      });
      _reconnect();
    });
    _player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      setState(() => _isBuffering = buffering);
    });
    _player.stream.width.listen((width) {
      final height = _player.state.height;
      if (!mounted || width == null || height == null || width <= 0 || height <= 0) {
        return;
      }
      final rotateClockwise = _shouldRotateClockwise(width, height);
      setState(() {
        _resolution = '${width.toInt()}x${height.toInt()}';
        _rotateClockwise = rotateClockwise;
      });
    });
  }

  Future<void> _restoreLastUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_rtspUrlKey);
    if (!mounted || saved == null || saved.trim().isEmpty) return;
    _urlController.text = saved;
  }

  Future<void> _saveLastUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rtspUrlKey, url);
  }

  bool _shouldRotateClockwise(num width, num height) {
    final ratio = width / height;
    final orientation = MediaQuery.orientationOf(context);
    if (orientation == Orientation.landscape) {
      return false;
    }
    if (ratio >= 1.2) return true;
    return false;
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _errorSub?.cancel();
    _player.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying || _isBuffering) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    if (!Platform.isAndroid) {
      setState(() => _lastError = '当前仅支持 Android 平台 RTSP 拉流');
      return;
    }
    final url = _urlController.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.toLowerCase() != 'rtsp') {
      setState(() => _lastError = 'RTSP 地址无效');
      return;
    }
    _startAt = DateTime.now();
    _firstFrameDuration = null;
    _lastError = '--';
    try {
      await _saveLastUrl(url);
      await _player.open(
        Media(url),
        play: true,
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastError = e.toString());
    }
  }

  Future<void> _stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _isBuffering = false;
    });
  }

  Future<void> _reconnect() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted || (!_isBuffering && _isPlaying)) return;
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Column(
      children: [
        if (!isLandscape)
          AppPanel(
            margin: const EdgeInsets.only(bottom: 6),
            child: _buildControlRow(),
          ),
        Expanded(
          child: AppPanel(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                Center(
                  child: RotatedBox(
                    quarterTurns: _rotateClockwise ? 1 : 0,
                    child: Video(controller: _videoController, controls: NoVideoControls, fit: BoxFit.contain),
                  ),
                ),
                _buildOsdStats(),
                if (isLandscape) _buildFloatingControls(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlRow() {
    return Row(
      children: [
        IconButton.outlined(onPressed: _showConfigSheet, icon: const Icon(Icons.tune_rounded)),
        const SizedBox(width: 8),
        Builder(
          builder: (context) {
            final c = Provider.of<AppThemeController?>(context);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return IconButton.outlined(
              onPressed: c == null ? null : () => c.toggleFromBrightness(Theme.of(context).brightness),
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            );
          },
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: Platform.isAndroid ? _togglePlay : null,
          icon: Icon(_isPlaying || _isBuffering ? Icons.stop_rounded : Icons.play_arrow_rounded),
          label: Text(_isPlaying || _isBuffering ? '停止拉流' : '开始拉流'),
        ),
      ],
    );
  }

  Widget _buildFloatingControls() {
    final c = Provider.of<AppThemeController?>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      right: 10,
      top: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(999)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _showConfigSheet,
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
                tooltip: '拉流设置',
              ),
              IconButton(
                onPressed: c == null ? null : () => c.toggleFromBrightness(Theme.of(context).brightness),
                icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: Colors.white),
                tooltip: '切换主题',
              ),
              IconButton(
                onPressed: Platform.isAndroid ? _togglePlay : null,
                icon: Icon(_isPlaying || _isBuffering ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white),
                tooltip: _isPlaying || _isBuffering ? '停止拉流' : '开始拉流',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOsdStats() {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 11.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('状态: ${_isPlaying ? '播放中' : (_isBuffering ? '缓冲中' : '未播放')}'),
              Text('首帧: ${_firstFrameDuration?.inMilliseconds ?? '--'} ms'),
              Text('分辨率: $_resolution'),
              Text('重连次数: $_reconnectCount'),
              const Text('传输: RTSP over TCP'),
              if (_lastError != '--') Text('错误: $_lastError'),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfigSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RTSP 拉流设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: _urlController, decoration: const InputDecoration(labelText: '拉流地址', hintText: 'rtsp://host:554/path')),
            const SizedBox(height: 12),
            const Text('传输方式: TCP（Phase 1 固定）', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('完成')),
            ),
          ],
        ),
      ),
    );
  }
}
