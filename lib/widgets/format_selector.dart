import 'package:flutter/material.dart';
import '../models/message_data.dart';
import '../utils/data_converter.dart';

/// 数据格式选择器组件
class FormatSelector extends StatelessWidget {
  final DataFormat value;
  final ValueChanged<DataFormat> onChanged;
  final String? label;
  final bool dense;

  const FormatSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 8),
        ],
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 12,
            vertical: dense ? 0 : 4,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DataFormat>(
              value: value,
              isDense: true,
              items: DataFormat.values.map((format) {
                return DropdownMenuItem<DataFormat>(
                  value: format,
                  child: Text(
                    DataConverter.getFormatName(format),
                    style: TextStyle(fontSize: dense ? 12 : 14),
                  ),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 编码选择器组件
class EncodingSelector extends StatelessWidget {
  final CharEncoding value;
  final ValueChanged<CharEncoding> onChanged;
  final String? label;
  final bool dense;

  const EncodingSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 8),
        ],
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 12,
            vertical: dense ? 0 : 4,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CharEncoding>(
              value: value,
              isDense: true,
              items: CharEncoding.values.map((encoding) {
                return DropdownMenuItem<CharEncoding>(
                  value: encoding,
                  child: Text(
                    DataConverter.getEncodingName(encoding),
                    style: TextStyle(fontSize: dense ? 12 : 14),
                  ),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 双格式选择器（发送和接收格式独立选择）
class DualFormatSelector extends StatelessWidget {
  final DataFormat sendFormat;
  final DataFormat receiveFormat;
  final ValueChanged<DataFormat> onSendFormatChanged;
  final ValueChanged<DataFormat> onReceiveFormatChanged;

  const DualFormatSelector({
    super.key,
    required this.sendFormat,
    required this.receiveFormat,
    required this.onSendFormatChanged,
    required this.onReceiveFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FormatSelector(
            label: '发送',
            value: sendFormat,
            onChanged: onSendFormatChanged,
            dense: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FormatSelector(
            label: '接收',
            value: receiveFormat,
            onChanged: onReceiveFormatChanged,
            dense: true,
          ),
        ),
      ],
    );
  }
}

/// 格式和编码选择器组合（用于显示区域）
class FormatEncodingSelector extends StatelessWidget {
  final DataFormat format;
  final CharEncoding encoding;
  final ValueChanged<DataFormat> onFormatChanged;
  final ValueChanged<CharEncoding> onEncodingChanged;
  final String? formatLabel;
  final String? encodingLabel;

  const FormatEncodingSelector({
    super.key,
    required this.format,
    required this.encoding,
    required this.onFormatChanged,
    required this.onEncodingChanged,
    this.formatLabel = '格式',
    this.encodingLabel = '编码',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FormatSelector(
          label: formatLabel,
          value: format,
          onChanged: onFormatChanged,
          dense: true,
        ),
        const SizedBox(width: 16),
        EncodingSelector(
          label: encodingLabel,
          value: encoding,
          onChanged: onEncodingChanged,
          dense: true,
        ),
      ],
    );
  }
}
