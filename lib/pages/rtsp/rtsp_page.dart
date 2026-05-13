import 'package:flutter/material.dart';

import '../../widgets/widgets.dart';

class RtspPage extends StatelessWidget {
  const RtspPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        AppPanel(
          child: Row(
            children: [
              SectionBadge(
                icon: Icons.construction_rounded,
                label: '功能预留',
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'RTSP 页当前仅保留占位符，后续重构完成后再接入实际拉流逻辑。',
                  style: TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AppPanel(
            margin: EdgeInsets.zero,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.videocam_off_rounded,
                      size: 54,
                      color: scheme.outline,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'RTSP 功能暂未启用',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '当前版本已移除 RTSP 播放器和推流相关业务逻辑，避免影响后续代码重构。保留页面入口用于后续恢复和重新设计。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
